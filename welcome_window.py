from PyQt6.QtCore import pyqtSignal, Qt
from PyQt6.QtWidgets import QMainWindow
from PyQt6.uic import loadUi


class WelcomeWindow(QMainWindow):
    phone_check_signal = pyqtSignal(str, int)

    def __init__(self, db):
        super().__init__()
        loadUi("ui/welcome.ui", self)

        # Сохраняем переданное соединение с базой данных
        self.db = db

        # Настройка полей
        self._setup_ui()

    def _setup_ui(self):
        self.avt_btn.clicked.connect(self.authorization)
        self.number_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.number_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.number_edit.setInputMask("+7 (999) 999-99-99")
        self.number_edit.mousePressEvent = self._ignore_mouse_event

        # Убрать
        self.number_edit.setText("+7 (940) 984-69-39")

    def authorization(self):
        checked_button = self.ChouseGroup.checkedButton()

        if not checked_button:
            self.error_phone_label.setText("Выберите тип авторизации!")
            return

        type_avt = "Clients" if checked_button.objectName() == "radioCleint" else "Mechanics"

        number = self.number_edit.text()
        valid_len = 18

        if len(number) != valid_len:
            self.error_phone_label.setText('Неверно введен номер телефона!')
            return

        self.error_phone_label.clear()

        cleaned_number = number.replace("(", "").replace(")", "").replace("-", "").replace(" ", "")

        valid_user = self.check_phone_in_db(cleaned_number, type_avt)

        if valid_user:
            self.phone_check_signal.emit(type_avt, valid_user)  # Сигнал с типом авторизации
        else:
            self.error_phone_label.setText('Пользователь не найден!')

    def check_phone_in_db(self, phone_number, type_avt):
        if type_avt == "Clients":
            name_phone = "phone"
            query = f"SELECT * FROM {type_avt} WHERE {name_phone} = %s"
            result = self.db.fetch_one(query, (phone_number,))

        else:
            name_phone = "phone_number"
            query = f"SELECT * FROM {type_avt} WHERE {name_phone} = %s"
            result = self.db.fetch_one(query, (phone_number,))
        if result:
            print(result)
            id = result[0]
            return id

    def _ignore_mouse_event(self, event):
        pass
