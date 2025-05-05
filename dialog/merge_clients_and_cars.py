import datetime
from PyQt6.QtWidgets import QDialog, QVBoxLayout, QTableView
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class MergeClientsAndCarsDialog(QDialog):
    def __init__(self, qt_db):
        super().__init__()
        self.setWindowTitle("Информация об автомобилях")
        self.resize(800, 600)

        self.qt_db = qt_db
        self.model = QSqlQueryModel(self)
        self.table_view = QTableView(self)
        self.table_view.setModel(self.model)

        layout = QVBoxLayout()
        layout.addWidget(self.table_view)
        self.setLayout(layout)

        self.load_car_info()

    def load_car_info(self):
        query = QSqlQuery(self.qt_db)
        query_text = "SELECT * FROM car_full_info_view;"

        if not query.exec(query_text):
            print("Ошибка выполнения запроса:", query.lastError().text())
            return

        self.model.setQuery(query)
