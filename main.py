import sys
from PyQt6.QtWidgets import QApplication, QMainWindow
from database_manageer import DatabaseManager
from welcome_window import WelcomeWindow  # импортируем окно приветствия
from mainwindow_administrator import MainWindowAdministrator


class CarService():
    def __init__(self):
        # Подключение к базе данных
        self.db = DatabaseManager()
        self.db.connect()

        # Открытие окна приветствия и передача объекта базы данных
        self.welcome_window = WelcomeWindow(self.db)  # передаем db в окно приветствия
        self.welcome_window.phone_check_signal.connect(self.handle_phone_check_signal)

        self.welcome_window.show()

    def handle_phone_check_signal(self, type_avt, id):
        # Обработка сигнала, который пришел из WelcomeWindow
        self.welcome_window.close()

        self.mainwindow_admnistator = MainWindowAdministrator(self.db, id)
        self.mainwindow_admnistator.show()

        print(type_avt, id)

    def closeEvent(self, event):
        # Закрытие соединения с базой данных при выходе
        self.db.disconnect()
        event.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    car_service = CarService()
    sys.exit(app.exec())  # Запуск приложения
