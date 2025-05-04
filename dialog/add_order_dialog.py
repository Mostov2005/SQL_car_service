import sys
import os
import datetime

from PyQt6.QtWidgets import QDialog, QApplication
from PyQt6.uic import loadUi
from PyQt6.QtCore import pyqtSignal, Qt
from database_manageer import *
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery
from PyQt6.QtWidgets import QSizePolicy


class AddOrderDialog(QDialog):
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'add_order_dialog.ui')
        loadUi(ui_path, self)

        self.db = db_manager

        self.number_client_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.number_client_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.number_client_edit.setInputMask("+7 (999) 999-99-99")
        self.number_client_edit.mousePressEvent = self._ignore_mouse_event

        # policy = QSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        # self.error_label.setSizePolicy(policy)

        self.id_client: int | None = None
        self.id_mechanic: int | None = None
        self.id_car: int | None = None

        self.phone_number_client = ''
        self.name_client = ''
        self.license_plate = ''

        # Потом убрать:
        self.number_client_edit.setText("+7 (913) 136-41-83")

        self.search_client_btn.clicked.connect(self.search_cleint)

        self.info_order = (" Информация о заказе:\n"
                           f"Дата заказа: {datetime.date.today()}\n"
                           f'Номер Клиента: {self.phone_number_client}\n'
                           f'ФИО Клиента: {self.name_client}\n'
                           f'Номер автомобиля: {self.license_plate}\n'
                           )

        self.update_info_label()

    def search_cleint(self):
        def load_cars_for_client(client_id: int):
            query = """
                SELECT car_id, model, color, license_plate
                FROM cars
                WHERE owner_id = %s
            """
            params = (client_id,)
            result = self.db.fetch_all(query, params)
            print(result)
            self.car_combobox.clear()  # очищаем список перед загрузкой новых данных
            if result:
                for row in result:
                    car_id = row[0]
                    model = row[1]
                    color = row[2]
                    license_plate = row[3]
                    display_text = f"{model} - {color} - {license_plate}"

                    self.car_combobox.addItem(display_text, car_id)
            else:
                self.set_error_label_text("У данного клиента нет сохраненных автомобилей")

        number = self.number_client_edit.text()
        valid_len = 18

        if len(number) != valid_len:
            self.set_error_label_text('Неверно введен номер телефона!')
            return

        cleaned_number = number.replace("(", "").replace(")", "").replace("-", "").replace(" ", "")
        query = f"SELECT * FROM CLIENTS WHERE phone = %s"
        result = self.db.fetch_one(query, (cleaned_number,))
        if result:
            self.set_error_label_text("Клиент найден!", "green")

            self.id_client = result[0]
            self.name_client = result[1]
            self.phone_number_client = number

            load_cars_for_client(result[0])

        else:
            self.set_error_label_text("Клиент не найден!")

    def set_error_label_text(self, text, color='red'):
        self.error_label.setText(text)
        self.error_label.setStyleSheet(f"color: {color};")

    def _ignore_mouse_event(self, event):
        pass

    def update_info_label(self):
        self.info_order_label.setText(self.info_order)

    def get_order_data(self):
        """
        Заглушка: Здесь извлекаются данные из полей формы.
        Вернёт словарь, пригодный для добавления в БД.
        """
        return {
            'client_id': self.client_combo.currentData(),  # пример
            'car_id': self.car_combo.currentData(),
            'workplace_id': self.workplace_combo.currentData(),
            'payment_type_id': self.payment_combo.currentData(),
            'order_date': self.date_edit.date().toString("yyyy-MM-dd"),
            'services': [],  # если есть
            'parts': [],  # если есть
        }


# Тестовое открытие диалога отдельно
if __name__ == "__main__":
    db_manager = DatabaseManager()
    db_manager.connect()

    app = QApplication(sys.argv)
    dialog = AddOrderDialog(db_manager)
    if dialog.exec():
        data = dialog.get_order_data()
        print("Введённые данные:", data)
    else:
        print("Окно закрыто без сохранения")
    sys.exit(0)
