import sys
import os
from PyQt6.QtWidgets import QApplication, QDialog, QLineEdit, QPushButton, QLabel
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtCore import pyqtSignal, Qt


class AddCarDialog(QDialog):
    def __init__(self, db, phone_number=None, parent=None):
        super().__init__(parent)
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'add_car_dialog.ui')
        loadUi(ui_path, self)

        self.db = db  # База данных

        self.number_client_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.number_client_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.number_client_edit.setInputMask("+7 (999) 999-99-99")
        self.number_client_edit.mousePressEvent = self._ignore_mouse_event

        if phone_number:
            self.number_client_edit.setText(phone_number)
            self.number_client_edit.setReadOnly(True)
            self.number_client_edit.setStyleSheet(
                "background-color: #f0f0f0;")  # серый фон, чтобы показать, что поле неактивно

        # Связать кнопки с функциями
        self.add_button.clicked.connect(self.add_car)

    def _ignore_mouse_event(self, event):
        pass

    def add_car(self):
        phone = self.number_client_edit.text()
        model = self.model_edit.text()
        color = self.color_edit.text()
        license_plate = self.license_plate_edit.text()

        if not model or not phone or not color or not license_plate:
            self.error_label.setText("Все поля должны быть заполнены!")
            self.error_label.setStyleSheet(f"color: red;")

            return

        valid_len = 18
        if len(phone) != valid_len:
            self.error_label.setText('Неверно введен номер телефона!')
            self.error_label.setStyleSheet(f"color: red;")
            return

        cleaned_number = phone.replace("(", "").replace(")", "").replace("-", "").replace(" ", "")

        # Добавление в базу данных
        query = "CALL add_car_for_client(%s, %s, %s, %s)"
        try:
            self.db.execute(query, (cleaned_number, model, color, license_plate))
            self.error_label.setText("Автомобиль добавлен успешно!")
            self.error_label.setStyleSheet(f"color: green;")
        except Exception as e:
            self.error_label.setText(f"Ошибка добавления: {e}")
            self.error_label.setStyleSheet(f"color: red;")


# Запуск для тестирования
if __name__ == "__main__":
    app = QApplication(sys.argv)
    db_manager = DatabaseManager()
    db_manager.connect()
    dialog = AddCarDialog(db_manager)
    dialog.show()

    sys.exit(app.exec())
