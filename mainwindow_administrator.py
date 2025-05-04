import sys
from PyQt6.QtWidgets import QApplication, QMainWindow
from database_manageer import DatabaseManager
from welcome_window import WelcomeWindow  # импортируем окно приветствия
from PyQt6.QtCore import pyqtSignal, Qt
from PyQt6.uic import loadUi
from PyQt6.QtWidgets import QSizePolicy

from tabs.tab_orders import OrdersTab  # Импортируем класс твоей вкладки


class MainWindowAdministrator(QMainWindow):
    def __init__(self, db):
        super().__init__()
        loadUi("ui/mainwindow_admin.ui", self)
        self.db = db

        self.showMaximized()

        self.orders_tab = OrdersTab()
        self.tabWidget.addTab(self.orders_tab, "Заказы")

        # self.tableWidget.removeTab(0)
        # self.tableWidget.insertTab(0, self.orders_tab, "Заказы")

        # Подключение к базе данных
        self.db = DatabaseManager()
        self.db.connect()

    def closeEvent(self, event):
        # Закрытие соединения с базой данных при выходе
        self.db.disconnect()
        event.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    main_window = MainWindowAdministrator()
    main_window.show()
    sys.exit(app.exec())  # Запуск приложения
