import sys
import datetime
from PyQt6.QtWidgets import QApplication, QMainWindow
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery
from PyQt6.QtWidgets import QWidget, QApplication, QHeaderView

from tabs.tab_orders import OrdersTab
from tabs.tab_cars import CarsTab
from tabs.tab_clients import ClientsTab
from tabs.tab_parts import PartsTab
from tabs.tab_parts_in_orders import PartsInOrdersTab
from tabs.tab_mechanicks import MechanicksTab
from tabs.tab_payment_types import PaymentTypesTab
from tabs.tab_services import ServicesTab
from tabs.tab_servises_in_orders import Services_in_orders_Tab
from tabs.tab_workplaces import WorkplacesTab

from dialog.add_client_dialog import AddClientDialog
from dialog.add_car_dialog import AddCarDialog
from dialog.add_order_dialog import AddOrderDialog
from dialog.merge_clients_and_cars import MergeClientsAndCarsDialog
from dialog.report_orders import ReportOrdersDialog


class MainWindowAdministrator(QMainWindow):
    def __init__(self, db_manager: DatabaseManager, admin_id: int):
        super().__init__()
        loadUi("ui/mainwindow_admin.ui", self)
        self.showMaximized()

        # Обычное подключение для ручных запросов
        self.db_manager = db_manager
        self.qt_db = self.db_manager.create_qt_connection()
        self.admin_id = admin_id

        self.completion_label_info()
        self.load_last_orders_for_30_days()
        self.load_tabs()

        self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)

        self.refresh_btn.clicked.connect(self.load_last_orders_for_30_days)

        self.place_order_btn.clicked.connect(self.open_add_order_dialog)
        self.add_client_btn.clicked.connect(self.open_add_client_dialog)
        self.add_car_btn.clicked.connect(self.open_add_car_dialog)
        self.merge_clients_and_car_btn.clicked.connect(self.open_merge_clients_and_car_dialog)
        self.report_btn.clicked.connect(self.open_report_orders_dialog)

    def open_add_client_dialog(self):
        dialog = AddClientDialog(self.db_manager, parent=self)
        dialog.exec()

    def open_add_car_dialog(self):
        dialog = AddCarDialog(self.db_manager, phone_number=None, parent=self)
        dialog.exec()

    def open_add_order_dialog(self):
        dialog = AddOrderDialog(self.db_manager, parent=self)
        dialog.exec()

    def open_merge_clients_and_car_dialog(self):
        dialog = MergeClientsAndCarsDialog(self.qt_db)
        dialog.exec()

    def open_report_orders_dialog(self):
        dialog = ReportOrdersDialog(self.qt_db)
        dialog.exec()

    def closeEvent(self, event):
        # Закрытие обоих соединений
        self.db_manager.disconnect()

        if self.qt_db and self.qt_db.isOpen():
            self.qt_db.close()

        event.accept()

    def load_tabs(self):
        self.orders_tab = OrdersTab(self.qt_db)
        self.cars_tab = CarsTab(self.qt_db)
        self.clints_tab = ClientsTab(self.qt_db)
        self.parts_tab = PartsTab(self.qt_db)
        self.parts_in_orders_tab = PartsInOrdersTab(self.qt_db)
        self.mechanicks_tab = MechanicksTab(self.qt_db, admin_id=self.admin_id)
        self.payment_types_tab = PaymentTypesTab(self.qt_db)
        self.services_tab = ServicesTab(self.qt_db)
        self.services_in_orders_tab = Services_in_orders_Tab(self.qt_db)
        self.workplaces_tab = WorkplacesTab(self.qt_db)

        self.tabWidget.addTab(self.orders_tab, "Заказы")
        self.tabWidget.addTab(self.clints_tab, "Клиенты")
        self.tabWidget.addTab(self.cars_tab, "Автомобили")
        self.tabWidget.addTab(self.mechanicks_tab, "Персонал")
        self.tabWidget.addTab(self.parts_tab, "Склад")
        self.tabWidget.addTab(self.services_tab, "Услуги")
        self.tabWidget.addTab(self.parts_in_orders_tab, "Запчасти в заказе")
        self.tabWidget.addTab(self.services_in_orders_tab, "Услуги в заказе")
        self.tabWidget.addTab(self.payment_types_tab, "Типы оплаты")
        self.tabWidget.addTab(self.workplaces_tab, "Рабочие места")

    def completion_label_info(self):
        query = """
            SELECT mechanic_id, full_name, phone_number, qualification, salary, experience
            FROM mechanics
            WHERE mechanic_id = %s
        """
        result = self.db_manager.fetch_one(query, (self.admin_id,))

        info_user = (
            f'Добро пожаловать, {result[1]}\n'
            f'Ваш номер телефона: {result[2]}\n'
            f'Квалификация: {result[3]}\n'
            f'Зарплата: {result[4]}\n'
            f'Опыт работы: {result[5]}'
        )

        self.label_info.setText(info_user)

        self.date_today = datetime.date.today()
        self.label_data.setText(f'Текущая дата: {self.date_today}')

    def load_last_orders_for_30_days(self):
        self.model = QSqlQueryModel(self)
        query = QSqlQuery(self.qt_db)
        date_30_days_ago = self.date_today - datetime.timedelta(days=30)

        query_text = f"""
            SELECT Order_ID, Service_name, Order_Date, Total_Amount
            FROM Mechanic_Orders_View
            WHERE Mechanic_ID = {self.admin_id}
              AND Order_Date >= '{date_30_days_ago}'
            ORDER BY Order_Date DESC
        """
        query.exec(query_text)

        self.model.setQuery(query)
        self.tableView.setModel(self.model)


if __name__ == "__main__":
    app = QApplication(sys.argv)

    # 1. Обычное подключение
    db_manager = DatabaseManager()
    db_manager.connect()

    # 2. Передаем его в главное окно
    main_window = MainWindowAdministrator(db_manager, 3)
    main_window.show()

    sys.exit(app.exec())
