import datetime
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QTableView, QLabel,
    QHeaderView, QDateEdit, QPushButton
)
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery
from PyQt6.QtCore import QDate


class ReportPopularServicesDialog(QDialog):
    def __init__(self, qt_db):
        super().__init__()
        self.setWindowTitle("Популярные услуги за выбранный период")
        self.resize(800, 600)

        self.qt_db = qt_db

        # Метки
        self.label_count = QLabel("Оказано разных услуг: ...", self)
        self.label_sum = QLabel("Общая сумма: ...", self)

        # Выбор дат
        self.date_from = QDateEdit(self)
        self.date_from.setCalendarPopup(True)
        self.date_from.setDate(QDate.currentDate().addDays(-30))

        self.date_to = QDateEdit(self)
        self.date_to.setCalendarPopup(True)
        self.date_to.setDate(QDate.currentDate())

        self.btn_load = QPushButton("Обновить отчет", self)
        self.btn_load.clicked.connect(self.load_report)

        date_layout = QHBoxLayout()
        date_layout.addWidget(QLabel("С:"))
        date_layout.addWidget(self.date_from)
        date_layout.addWidget(QLabel("По:"))
        date_layout.addWidget(self.date_to)
        date_layout.addWidget(self.btn_load)

        # Таблица
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)
        self.table_view.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

        # Разметка
        layout = QVBoxLayout()
        layout.addLayout(date_layout)
        layout.addWidget(self.label_count)
        layout.addWidget(self.label_sum)
        layout.addWidget(self.table_view)
        self.setLayout(layout)

        self.load_report()

    def load_report(self):
        date_from = self.date_from.date().toString("yyyy-MM-dd")
        date_to = self.date_to.date().toString("yyyy-MM-dd")

        query = QSqlQuery(self.qt_db)
        query_text = f"""
            SELECT 
                s.service_name AS "Услуга",
                COUNT(*) AS "Количество оказаний",
                SUM(s.price) AS "Общая сумма (₽)"
            FROM services_in_orders sio
            JOIN services s ON sio.service_id = s.service_id
            JOIN orders o ON sio.order_id = o.order_id
            WHERE o.order_date BETWEEN '{date_from}' AND '{date_to}'
            GROUP BY s.service_name
            ORDER BY "Количество оказаний" DESC;
        """

        if not query.exec(query_text):
            print("Ошибка выполнения запроса:", query.lastError().text())
            return

        self.model.setQuery(query)

        # Статистика
        summary_query = QSqlQuery(self.qt_db)
        summary_text = f"""
            SELECT 
                COUNT(DISTINCT s.service_id) AS service_count,
                SUM(s.price) AS total_sum
            FROM services_in_orders sio
            JOIN services s ON sio.service_id = s.service_id
            JOIN orders o ON sio.order_id = o.order_id
            WHERE o.order_date BETWEEN '{date_from}' AND '{date_to}';
        """

        if summary_query.exec(summary_text) and summary_query.next():
            count = summary_query.value(0)
            total = summary_query.value(1)
            self.label_count.setText(f"Оказано разных услуг: {count}")
            self.label_sum.setText(f"Общая сумма: {total if total is not None else 0}₽")
        else:
            self.label_count.setText("Оказано разных услуг: ошибка")
            self.label_sum.setText("Общая сумма: ошибка")
