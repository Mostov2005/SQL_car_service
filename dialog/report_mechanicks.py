import datetime
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QTableView, QLabel, QHeaderView,
    QLineEdit, QPushButton, QHBoxLayout
)
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class ReportMechanicWorkloadDialog(QDialog):
    def __init__(self, qt_db):
        super().__init__()
        self.setWindowTitle("Занятость механиков за последний месяц")
        self.resize(800, 600)

        self.qt_db = qt_db

        # Метки
        self.label_count = QLabel("Механиков задействовано: ...", self)
        self.label_total = QLabel("Всего оказано услуг: ...", self)

        # Поле для фильтрации по имени механика
        self.input_mechanic = QLineEdit(self)
        self.input_mechanic.setPlaceholderText("Введите имя механика...")

        # Кнопка для обновления отчета
        self.btn_load = QPushButton("Обновить отчет", self)
        self.btn_load.clicked.connect(self.load_report)

        # Лэйаут для фильтра
        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("Фильтр по механику:"))
        filter_layout.addWidget(self.input_mechanic)
        filter_layout.addWidget(self.btn_load)

        # Таблица
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)
        self.table_view.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

        # Основной лэйаут
        layout = QVBoxLayout()
        layout.addLayout(filter_layout)
        layout.addWidget(self.label_count)
        layout.addWidget(self.label_total)
        layout.addWidget(self.table_view)
        self.setLayout(layout)

        self.load_report()

    def load_report(self):
        date_30_days_ago = datetime.date.today() - datetime.timedelta(days=30)
        mechanic_filter = self.input_mechanic.text().strip()

        # Формируем условие WHERE с фильтром по имени, если оно указано
        mechanic_condition = ""
        if mechanic_filter:
            mechanic_condition = f"AND m.full_name LIKE '%{mechanic_filter}%'"

        query = QSqlQuery(self.qt_db)
        query_text = f"""
            SELECT 
                m.full_name AS "Механик",
                COUNT(*) AS "Количество услуг",
                SUM(sio.quantity * s.price) AS "Общая сумма (₽)"
            FROM services_in_orders sio
            JOIN services s ON sio.service_id = s.service_id
            JOIN mechanics m ON sio.mechanic_id = m.mechanic_id
            JOIN orders o ON sio.order_id = o.order_id
            WHERE o.order_date >= '{date_30_days_ago}' {mechanic_condition}
            GROUP BY m.full_name
            ORDER BY "Количество услуг" DESC;
        """

        if not query.exec(query_text):
            print("Ошибка выполнения запроса:", query.lastError().text())
            return

        self.model.setQuery(query)

        # Статистика
        summary_query = QSqlQuery(self.qt_db)
        summary_text = f"""
            SELECT 
                COUNT(DISTINCT sio.mechanic_id) AS mechanic_count,
                SUM(sio.quantity) AS total_services
            FROM services_in_orders sio
            JOIN mechanics m ON sio.mechanic_id = m.mechanic_id
            JOIN orders o ON sio.order_id = o.order_id
            WHERE o.order_date >= '{date_30_days_ago}' {mechanic_condition};
        """

        if summary_query.exec(summary_text) and summary_query.next():
            count = summary_query.value(0)
            total = summary_query.value(1)
            self.label_count.setText(f"Механиков задействовано: {count}")
            self.label_total.setText(f"Всего оказано услуг: {total}")
        else:
            self.label_count.setText("Механиков задействовано: ошибка")
            self.label_total.setText("Всего оказано услуг: ошибка")
