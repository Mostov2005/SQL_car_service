import datetime
from PyQt6.QtWidgets import QDialog, QVBoxLayout, QTableView, QLabel, QHeaderView
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class ReportPopularServicesDialog(QDialog):
    def __init__(self, qt_db):
        super().__init__()
        self.setWindowTitle("Популярные услуги за последний месяц")
        self.resize(800, 600)

        self.qt_db = qt_db

        # Метки
        self.label_count = QLabel("Оказано разных услуг: ...", self)
        self.label_sum = QLabel("Общая сумма: ...", self)

        # Таблица
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)
        self.table_view.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

        # Разметка
        layout = QVBoxLayout()
        layout.addWidget(self.label_count)
        layout.addWidget(self.label_sum)
        layout.addWidget(self.table_view)
        self.setLayout(layout)

        self.load_report()

    def load_report(self):
        date_30_days_ago = datetime.date.today() - datetime.timedelta(days=30)
        query = QSqlQuery(self.qt_db)

        query_text = f"""
            SELECT 
                s.service_name AS "Услуга",
                COUNT(*) AS "Количество оказаний",
                SUM(s.price) AS "Общая сумма (₽)"
            FROM services_in_orders sio
            JOIN services s ON sio.service_id = s.service_id
            JOIN orders o ON sio.order_id = o.order_id
            WHERE o.order_date >= '{date_30_days_ago}'
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
            WHERE o.order_date >= '{date_30_days_ago}';
        """

        if summary_query.exec(summary_text) and summary_query.next():
            count = summary_query.value(0)
            total = summary_query.value(1)
            self.label_count.setText(f"Оказано разных услуг: {count}")
            self.label_sum.setText(f"Общая сумма: {total}₽")
        else:
            self.label_count.setText("Оказано разных услуг: ошибка")
            self.label_sum.setText("Общая сумма: ошибка")
