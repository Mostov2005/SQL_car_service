import sys
import os
from PyQt6.QtWidgets import QApplication, QDialog, QLineEdit, QPushButton, QLabel
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtCore import pyqtSignal, Qt


class AddClientDialog(QDialog):
    def __init__(self, db, parent=None):
        super().__init__(parent)
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'add_client_dialog.ui')
        loadUi(ui_path, self)

        self.db = db  # База данных

        self.number_client_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.number_client_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.number_client_edit.setInputMask("+7 (999) 999-99-99")
        self.number_client_edit.mousePressEvent = self._ignore_mouse_event

        # Связать кнопки с функциями
        self.add_button.clicked.connect(self.add_client)

    def _ignore_mouse_event(self, event):
        pass

    def add_client(self):
        phone = self.number_client_edit.text()
        name = self.fio_client_edit.text()
        valid_len = 18

        if len(phone) != valid_len:
            self.error_label.setText('Неверно введен номер телефона!')
            self.error_label.setStyleSheet(f"color: red;")
            return

        cleaned_number = phone.replace("(", "").replace(")", "").replace("-", "").replace(" ", "")
        # Валидация
        if not name or not cleaned_number:
            self.error_label.setText("Все поля должны быть заполнены!")
            self.error_label.setStyleSheet(f"color: red;")

            return

        # Добавление в базу данных
        query = """
            INSERT INTO clients (full_name, phone)
            VALUES (%s, %s)
        """
        try:
            self.db.execute(query, (name, cleaned_number))
            self.error_label.setText("Клиент добавлен успешно!")
            self.error_label.setStyleSheet(f"color: green;")

        except Exception as e:
            self.error_label.setText(f"Ошибка добавления: {e}")
            self.error_label.setStyleSheet(f"color: red;")


# Запуск для тестирования
if __name__ == "__main__":
    app = QApplication(sys.argv)
    db_manager = DatabaseManager()
    db_manager.connect()
    dialog = AddClientDialog(db_manager)
    dialog.show()

    sys.exit(app.exec())
