import sys
from PyQt6.QtWidgets import QApplication, QMainWindow
from PyQt6.uic import loadUi


class WelcomeWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        # Загружаем интерфейс из .ui файла
        loadUi("welcome_window.ui", self)  # Считываем интерфейс

        # Дополнительно можно настроить параметры, если нужно
        self.setWindowTitle("Окно приветствия")  # Заголовок окна


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = WelcomeWindow()  # Создаем окно
    window.show()  # Отображаем окно
    sys.exit(app.exec())  # Запускаем цикл событий
