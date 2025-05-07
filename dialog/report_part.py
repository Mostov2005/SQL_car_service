import datetime
from PyQt6.QtWidgets import QDialog, QVBoxLayout, QTableView, QLabel
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class ReportPartsSoldDialog(QDialog):
    def __init__(self, db_manager, qt_db):
        super().__init__()
        self.setWindowTitle("Проданные запчасти за последний месяц")
        self.resize(800, 600)

        self.db_manager = db_manager
        self.qt_db = qt_db

        # Метки
        self.label_count = QLabel("Наименований продано: ...", self)
        self.label_sum = QLabel("Общая выручка: ...", self)

        # Таблица
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)

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
                p.part_name AS "Название запчасти",
                SUM(pio.quantity) AS "Количество продано",
                SUM(pio.quantity * p.price) AS "Выручка (₽)"
            FROM parts_in_orders pio
            JOIN parts p ON pio.part_id = p.part_id
            JOIN orders o ON pio.order_id = o.order_id
            WHERE o.order_date >= '{date_30_days_ago}'
            GROUP BY p.part_name
            ORDER BY "Количество продано" DESC;
        """

        if not query.exec(query_text):
            print("Ошибка выполнения запроса:", query.lastError().text())
            return

        self.model.setQuery(query)

        # Подсчёт общей статистики
        summary_query = QSqlQuery(self.qt_db)
        summary_text = f"""
            SELECT 
                COUNT(DISTINCT pio.part_id) AS part_count,
                SUM(pio.quantity * p.price) AS total_revenue
            FROM parts_in_orders pio
            JOIN parts p ON pio.part_id = p.part_id
            JOIN orders o ON pio.order_id = o.order_id
            WHERE o.order_date >= '{date_30_days_ago}';
        """

        if summary_query.exec(summary_text) and summary_query.next():
            count = summary_query.value(0)
            total = summary_query.value(1)
            self.label_count.setText(f"Наименований продано: {count}")
            self.label_sum.setText(f"Общая выручка: {total}₽")
        else:
            self.label_count.setText("Наименований продано: ошибка")
            self.label_sum.setText("Общая выручка: ошибка")
