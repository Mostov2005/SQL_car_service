import datetime
from PyQt6.QtWidgets import QDialog, QVBoxLayout, QTableView, QLabel
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class ReportOrdersDialog(QDialog):
    def __init__(self, qt_db):
        super().__init__()
        self.setWindowTitle("Заказы за последние 30 дней")
        self.resize(800, 600)

        self.qt_db = qt_db

        # Метки для количества заказов и суммы
        self.label_count = QLabel("Количество заказов: ...", self)
        self.label_sum = QLabel("Общая сумма: ...", self)

        # Модель и таблица
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)

        # Разметка
        layout = QVBoxLayout()
        layout.addWidget(self.label_count)
        layout.addWidget(self.label_sum)
        layout.addWidget(self.table_view)
        self.setLayout(layout)

        self.load_recent_orders()

    def load_recent_orders(self):
        date_30_days_ago = datetime.date.today() - datetime.timedelta(days=30)
        query = QSqlQuery(self.qt_db)

        # Основной запрос для таблицы
        query_text = f"""
            SELECT *
            FROM orders
            WHERE order_date >= '{date_30_days_ago}'
            ORDER BY order_date DESC;
        """

        if not query.exec(query_text):
            print("Ошибка выполнения запроса:", query.lastError().text())
            return

        self.model.setQuery(query)

        # Запрос для статистики
        summary_query = QSqlQuery(self.qt_db)
        summary_text = f"""
            SELECT COUNT(*) AS order_count, SUM(total_amount) AS total_sum
            FROM orders
            WHERE order_date >= '{date_30_days_ago}';
        """

        if summary_query.exec(summary_text) and summary_query.next():
            count = summary_query.value(0)
            total = summary_query.value(1)
            self.label_count.setText(f"Количество заказов: {count}")
            self.label_sum.setText(f"Общая сумма: {total}₽")
        else:
            self.label_count.setText("Количество заказов: ошибка")
            self.label_sum.setText("Общая сумма: ошибка")
