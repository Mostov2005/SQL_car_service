import sys
import os
import datetime
import random

from PyQt6.QtWidgets import QDialog, QApplication, QComboBox, QSpinBox, QHeaderView
from PyQt6.uic import loadUi
from PyQt6.QtCore import pyqtSignal, Qt, QDate
from database_manageer import *
from PyQt6.QtSql import QSqlQueryModel, QSqlQuery


class AddOrderDialog(QDialog):
    def __init__(self, db_manager: DatabaseManager, phone_client=None, parent=None):
        super().__init__(parent)
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'add_order_dialog.ui')
        loadUi(ui_path, self)

        self.db = db_manager
        self.resize(1200, 800)
        if phone_client:
            self.number_client_edit.setText("+7 (913) 136-41-83")
            self.number_client_edit.setReadOnly(True)

        self.id_client: int | None = None
        self.id_car: int | None = None
        self.workplace_id: int | None = None
        self.payment_type_id: int | None = None
        self.date_order = datetime.date.today()
        self.parts = [[], []]
        self.services = [[], []]
        self.total_amount = 0

        self.phone_number_client = ''
        self.name_client = ''
        self.model_car = ''
        self.license_plate = ''
        self.workplace = ''
        self.payment_type = ''

        self.number_client_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.number_client_edit.setPlaceholderText("+7 (___) ___-__-__")
        self.number_client_edit.setInputMask("+7 (999) 999-99-99")
        self.number_client_edit.mousePressEvent = self._ignore_mouse_event

        # Настройки объектов
        self.car_combobox.currentIndexChanged.connect(self.on_car_selected)
        self.search_client_btn.clicked.connect(self.search_client)
        self.calendarWidget.selectionChanged.connect(self.on_date_selected)
        self.calendarWidget.setMinimumDate(QDate.currentDate())
        self.workplace_combobox.currentIndexChanged.connect(self.on_workplaces_selected)
        self.payment_type_combobox.currentIndexChanged.connect(self.on_payment_type_selected)
        self.add_parts_btn.clicked.connect(self.add_parts_on_table)
        self.add_services_btn.clicked.connect(self.add_services_on_table)
        self.calculate_price_btn.clicked.connect(self.calculate_price)
        self.oformlenie_zakaza_btn.clicked.connect(self.place_order)

        self.parts_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.services_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)

        # Для первой таблицы
        self.parts_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.parts_table.customContextMenuRequested.connect(
            lambda pos: self.handle_right_click_generic(self.parts_table, pos))
        self.parts_table.verticalHeader().setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.parts_table.verticalHeader().customContextMenuRequested.connect(
            lambda pos: self.handle_row_header_right_click_generic(self.parts_table, pos))

        # Для второй таблицы
        self.services_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.services_table.customContextMenuRequested.connect(
            lambda pos: self.handle_right_click_generic(self.services_table, pos))
        self.services_table.verticalHeader().setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.services_table.verticalHeader().customContextMenuRequested.connect(
            lambda pos: self.handle_row_header_right_click_generic(self.services_table, pos))

        self.parts_data = self.load_parts()
        self.services_data = self.load_services()

        self.update_info_label()
        self.load_workplaces()
        self.load_payment_types()

    def update_info_label(self):
        info_order = ("_____________Информация о заказе_____________\n"
                      f"Дата заказа: {self.date_order}\n"
                      f'Номер Клиента: {self.phone_number_client}\n'
                      f'ФИО Клиента: {self.name_client}\n'
                      f'Марка автомобиля: {self.model_car}\n'
                      f'Номер автомобиля: {self.license_plate}\n'
                      f'Рабочее место: {self.workplace}\n'
                      f'Тип оплаты: {self.payment_type}\n'
                      f'Сумма заказа: {self.total_amount}'
                      )
        self.info_order_label.setText(info_order)

    def search_client(self):
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

            self.load_cars_for_client(result[0])
        else:
            self.set_error_label_text("Клиент не найден!")

    def load_cars_for_client(self, client_id: int):
        query = """
            SELECT car_id, model, color, license_plate
            FROM cars
            WHERE owner_id = %s
        """
        params = (client_id,)
        result = self.db.fetch_all(query, params)

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

    def load_workplaces(self):
        query = "SELECT workplace_id, workplace_type FROM Workplaces"
        result = self.db.fetch_all(query)

        self.workplace_combobox.clear()
        for row in result:
            workplace_id, name = row
            self.workplace_combobox.addItem(name, workplace_id)

    def load_payment_types(self):
        query = "SELECT payment_type_id, payment_name FROM Payment_Types"
        result = self.db.fetch_all(query)

        self.payment_type_combobox.clear()
        for row in result:
            payment_type_id, name = row
            self.payment_type_combobox.addItem(name, payment_type_id)

    def load_parts(self):
        query = "SELECT part_id, manufacturer, part_name, price FROM Parts"
        return self.db.fetch_all(query)

    def load_services(self):
        query = "SELECT service_id, service_name, price FROM Services"
        return self.db.fetch_all(query)

    def add_parts_on_table(self):
        row_position = self.parts_table.rowCount()
        self.parts_table.insertRow(row_position)

        # Комбобокс с запчастями
        combo = QComboBox()
        for part_id, manufacturer, part_name, price in self.parts_data:
            display_text = f"{manufacturer} - {part_name} ({price}₽)"
            combo.addItem(display_text, part_id)
        self.parts_table.setCellWidget(row_position, 0, combo)

        # Спинбокс для количества
        spin = QSpinBox()
        spin.setMinimum(1)
        spin.setMaximum(100)
        self.parts_table.setCellWidget(row_position, 1, spin)

    def add_services_on_table(self):
        row_position = self.services_table.rowCount()
        self.services_table.insertRow(row_position)

        # Комбобокс с услугами
        combo = QComboBox()
        for service_id, service_name, price in self.services_data:
            display_text = f"{service_name} ({price}₽)"
            combo.addItem(display_text, service_id)
        self.services_table.setCellWidget(row_position, 0, combo)

        # Спинбокс для количества (можно удалить, если не нужен)
        spin = QSpinBox()
        spin.setMinimum(1)
        spin.setMaximum(10)
        self.services_table.setCellWidget(row_position, 1, spin)

    def on_car_selected(self, index):
        if index >= 0:
            car_id = self.car_combobox.itemData(index)
            car_text = self.car_combobox.itemText(index)

            self.id_car = car_id
            info_car = car_text.split(" - ")

            print(info_car)
            self.model_car, self.license_plate = info_car[0], info_car[-1]

            self.update_info_label()

    def on_date_selected(self):
        # Получаем выбранную дату
        selected_date = self.calendarWidget.selectedDate()
        formatted_date = selected_date.toString("yyyy-MM-dd")
        self.date_order = formatted_date
        self.update_info_label()

    def on_workplaces_selected(self, index):
        if index >= 0:
            self.workplace_id = self.workplace_combobox.currentData()  # вернет workplace_id
            self.workplace = self.workplace_combobox.currentText()  # вернет name

            self.update_info_label()

    def on_payment_type_selected(self, index):
        if index >= 0:
            self.payment_type_id = self.payment_type_combobox.currentData()
            self.payment_type = self.payment_type_combobox.currentText()
            print(self.payment_type)

            self.update_info_label()

    def get_parts_and_services(self):
        self.parts[0].clear()
        self.parts[1].clear()

        self.services[0].clear()
        self.services[1].clear()

        row_count = self.parts_table.rowCount()
        for row in range(row_count):
            combo = self.parts_table.cellWidget(row, 0)
            spin = self.parts_table.cellWidget(row, 1)
            if combo and spin:
                part_id = combo.currentData()
                quantity = spin.value()
                self.parts[0].append(part_id)
                self.parts[1].append(quantity)

        row_count = self.services_table.rowCount()
        for row in range(row_count):
            combo = self.services_table.cellWidget(row, 0)
            spin = self.services_table.cellWidget(row, 1)
            if combo and spin:
                service_id = combo.currentData()
                quantity = spin.value()
                self.services[0].append(service_id)
                self.services[1].append(quantity)

    def calculate_price(self):
        self.get_parts_and_services()

        query = "SELECT get_total_order_price_with_quantity(%s, %s, %s, %s);"
        price = self.db.fetch_one(query, (self.services[0],
                                          self.services[1],
                                          self.parts[0],
                                          self.parts[1]))
        self.total_amount = float(price[0])

        self.update_info_label()

    def place_order(self):
        self.calculate_price()
        mechanic_id = random.randint(0, 100000)

        if not all([
            self.id_client,
            self.id_car,
            self.workplace_id,
            self.payment_type_id,
            self.parts,  # parts должна быть список с двумя подсписками: [ID, количество]
            self.services,  # services должна быть список с двумя подсписками: [ID, количество]
        ]) or self.total_amount <= 0:
            self.set_error_label_text("Все поля должны быть заполнены!")
            return

            # Формируем запрос для вызова хранимой процедуры
        query = """
            CALL create_order_procedure(
                %s,  -- client_id
                %s,  -- car_id
                %s,  -- mechanic_id
                %s,  -- workplace_id
                CURRENT_DATE,  -- order_date
                %s,  -- payment_type_id
                %s,  -- services_ids (ID услуг)
                %s,  -- services_quantities (Количество услуг)
                %s,  -- parts_ids (ID запчастей)
                %s,  -- parts_quantities (Количество запчастей)
                %s   -- total_amount
            );
        """

        # Параметры для запроса
        params = (
            self.id_client,  # client_id
            self.id_car,  # car_id
            mechanic_id,  # mechanic_id
            self.workplace_id,  # workplace_id
            self.payment_type_id,  # payment_type_id
            self.services[0],  # services_ids (ID услуг)
            self.services[1],  # services_quantities (Количество услуг)
            self.parts[0],  # parts_ids (ID запчастей)
            self.parts[1],  # parts_quantities (Количество запчастей)
            self.total_amount  # total_amount
        )

        # Выполнение запроса с использованием метода execute вашего класса DatabaseManager
        try:
            self.db.execute(query, params)
            self.set_error_label_text("Заказ успешно размещён!", color='green')
        except Exception as e:
            print(f"Ошибка при размещении заказа: {e}")
            self.set_error_label_text(f"Ошибка при размещении заказа: {e}")

    def handle_right_click_generic(self, table, pos):
        index = table.indexAt(pos)
        if index.isValid():
            row = index.row()
            table.removeRow(row)

    def handle_row_header_right_click_generic(self, table, pos):
        header = table.verticalHeader()
        row = header.logicalIndexAt(pos)
        if row >= 0:
            table.removeRow(row)

    def set_error_label_text(self, text, color='red'):
        self.error_label.setText(text)
        self.error_label.setStyleSheet(f"color: {color};")

    def _ignore_mouse_event(self, event):
        pass


# Тестовое открытие диалога отдельно
if __name__ == "__main__":
    db_manager = DatabaseManager()
    db_manager.connect()

    n = "+79131364183"

    app = QApplication(sys.argv)
    dialog = AddOrderDialog(db_manager, phone_client=n)
    if dialog.exec():
        data = dialog.get_order_data()
        print("Введённые данные:", data)
    else:
        print("Окно закрыто без сохранения")
    sys.exit(0)
