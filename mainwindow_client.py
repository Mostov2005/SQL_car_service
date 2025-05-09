import sys
import datetime
from PyQt6.QtWidgets import QApplication, QMainWindow
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery
from PyQt6.QtWidgets import QWidget, QApplication, QHeaderView

from dialog.add_car_dialog import AddCarDialog
from dialog.add_order_dialog import AddOrderDialog
from dialog.edit_number_for_client_dialog import EditPhoneNumber


class MainWindowClient(QMainWindow):
    def __init__(self, db_manager: DatabaseManager, client_id: int):
        super().__init__()
        loadUi("ui/mainwindow_client.ui", self)
        self.showMaximized()

        # Обычное подключение для ручных запросов
        self.db_manager = db_manager
        self.qt_db = self.db_manager.create_qt_connection()
        self.client_id = client_id

        self.completion_label_info()
        self.get_cars()
        self.get_orders()

        self.tableView_cars.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.tableView_orders.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

        self.refresh_cars_btn.clicked.connect(self.get_cars)
        self.refresh_orders_btn.clicked.connect(self.get_orders)
        self.place_order_btn.clicked.connect(self.open_add_order_dialog)
        self.add_car_btn.clicked.connect(self.open_add_car_dialog)
        self.edit_phone_btn.clicked.connect(self.open_edit_phone_dialog)
        self.refresh_info_btn.clicked.connect(self.completion_label_info)

    def open_add_car_dialog(self):
        dialog = AddCarDialog(self.db_manager, phone_number=self.phone, parent=self)
        dialog.exec()

    def open_add_order_dialog(self):
        dialog = AddOrderDialog(self.db_manager, phone_client=self.phone, parent=self)
        dialog.exec()

    def open_edit_phone_dialog(self):
        dialog = EditPhoneNumber(self.db_manager, client_id=self.client_id, phone_number=self.phone, parent=self)
        dialog.exec()

    def closeEvent(self, event):
        # Закрытие обоих соединений
        self.db_manager.disconnect()

        if self.qt_db and self.qt_db.isOpen():
            self.qt_db.close()

        event.accept()

    def completion_label_info(self):
        query = """
            SELECT client_id, full_name, phone
            FROM clients
            WHERE client_id = %s
        """
        result = self.db_manager.fetch_one(query, (self.client_id,))

        info_user = (
            f'Добро пожаловать, {result[1]}\n'
            f'Ваш номер телефона: {result[2]}\n'
        )
        self.phone = result[2]
        self.label_info.setText(info_user)

    def get_cars(self):
        self.model = QSqlQueryModel(self)

        query = QSqlQuery(self.qt_db)
        query.prepare("""
            SELECT c.client_id, car.model, car.color, car.license_plate
            FROM clients c
            JOIN cars car ON c.client_id = car.owner_id
            WHERE c.client_id = ?
        """)
        query.addBindValue(self.client_id)  # <-- Вставляем значение параметра

        if not query.exec():
            print("Ошибка запроса:", query.lastError().text())
            return

        self.model.setQuery(query)
        self.tableView_cars.setModel(self.model)

    def get_orders(self):
        self.model = QSqlQueryModel(self)

        query = QSqlQuery(self.qt_db)
        query.prepare("""
            SELECT 
                o.order_date AS "Дата заказа",
                c.model AS "Модель",
                c.license_plate AS "Гос. номер",
                m.phone_number AS "Телефон механика",
                o.total_amount AS "Итоговая сумма"
            FROM orders o
            JOIN cars c ON o.car_id = c.car_id
            JOIN services_in_orders sio ON o.order_id = sio.order_id
            JOIN mechanics m ON sio.mechanic_id = m.mechanic_id
            WHERE o.client_id = ?
            ORDER BY o.order_date DESC;
        """)

        query.addBindValue(self.client_id)

        if not query.exec():
            print("Ошибка запроса:", query.lastError().text())
            return

        self.model.setQuery(query)
        self.tableView_orders.setModel(self.model)


if __name__ == "__main__":
    app = QApplication(sys.argv)

    # 1. Обычное подключение
    db_manager = DatabaseManager()
    db_manager.connect()

    # 2. Передаем его в главное окно
    main_window = MainWindowClient(db_manager, 3)
    main_window.show()

    sys.exit(app.exec())
