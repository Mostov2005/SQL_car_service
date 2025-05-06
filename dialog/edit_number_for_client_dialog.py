import sys
import os
from PyQt6.QtWidgets import QApplication, QDialog
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtCore import Qt


class EditPhoneNumber(QDialog):
    def __init__(self, db, client_id=3, phone_number=None, parent=None):
        super().__init__(parent)
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'edit_number_for_client_dialog.ui')
        loadUi(ui_path, self)

        self.client_id = client_id
        self.old_phone = phone_number
        self.db = db  # База данных

        self.old_phone_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.old_phone_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.old_phone_edit.setInputMask("+7 (999) 999-99-99")
        self.old_phone_edit.mousePressEvent = self._ignore_mouse_event
        self.old_phone_edit.setText(self.old_phone)
        self.old_phone_edit.setReadOnly(True)
        self.old_phone_edit.setStyleSheet(
            "background-color: #f0f0f0;")

        self.new_phone_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.new_phone_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.new_phone_edit.setInputMask("+7 (999) 999-99-99")
        self.new_phone_edit.mousePressEvent = self._ignore_mouse_event

        # Связать кнопки с функциями
        self.edit_btn.clicked.connect(self.edit_number)

    def _ignore_mouse_event(self, event):
        pass

    def edit_number(self):
        phone = self.new_phone_edit.text()

        if not phone:
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
        query = "SELECT update_client_phone(%s, %s);"
        try:
            # Выполнение запроса через execute
            self.db.execute(query, (self.client_id, cleaned_number))  # Вызываем процедуру без получения результата
            self.error_label.setText("Номер изменён успешно!")
            self.error_label.setStyleSheet(f"color: green;")
        except Exception as e:
            self.error_label.setText(f"Ошибка изменения номера: {e}")
            self.error_label.setStyleSheet(f"color: red;")


# Запуск для тестирования
if __name__ == "__main__":
    app = QApplication(sys.argv)
    db_manager = DatabaseManager()
    db_manager.connect()
    dialog = EditPhoneNumber(db_manager)
    dialog.show()

    sys.exit(app.exec())
