import sys
import os
from PyQt6.QtWidgets import QWidget, QApplication, QHeaderView
from PyQt6.uic import loadUi
from database_manageer import *
from PyQt6.QtSql import QSqlTableModel


class OrdersTab(QWidget):
    def __init__(self, dbmanager, qt_db):
        super().__init__()
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'tab_orders.ui')
        loadUi(ui_path, self)

        self.qt_db = qt_db
        self.dbmaneger = dbmanager

        self.model = QSqlTableModel(self, self.qt_db)
        self.model.setTable('orders')  # Название таблицы в БД

        self.save_btn.clicked.connect(self.save_changes)
        self.refresh_btn.clicked.connect(self.refresh_table)
        self.delete_btn.clicked.connect(self.delete_selected_row)
        self.search_client_btn.clicked.connect(self.search_on_name)

        # Привязать модель к TableView
        self.tableView.setModel(self.model)
        self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.model.setEditStrategy(QSqlTableModel.EditStrategy.OnManualSubmit)
        # Разрешить сортировку по столбцу
        self.tableView.setSortingEnabled(True)
        # Показывать стрелку направления сортировки
        self.tableView.horizontalHeader().setSortIndicatorShown(True)
        # Разрешить сортировку по столбцу
        self.tableView.setSortingEnabled(True)
        # Показывать стрелку направления сортировки
        self.tableView.horizontalHeader().setSortIndicatorShown(True)
        self.refresh_table()

    def search_on_name(self):
        name = self.name_edit.text().strip()

        if not name:
            self.model.setFilter("")
            self.model.select()
            self.error_label.setText("Введите имя для поиска.")
            self.error_label.setStyleSheet("color: red;")
            return

        try:
            # Получаем client_id по имени
            query = "SELECT client_id FROM clients WHERE full_name = %s LIMIT 1;"
            result = self.dbmaneger.fetch_one(query, (name,))

            if result:
                client_id = result[0]
                # Фильтруем таблицу заказов по client_id
                self.model.setFilter(f"client_id = {client_id}")
                self.model.select()
                self.error_label.setText(f"Показаны заказы клиента: {name}")
                self.error_label.setStyleSheet("color: green;")
            else:
                self.error_label.setText("Клиент с таким именем не найден.")
                self.error_label.setStyleSheet("color: red;")
                self.refresh_table()

        except Exception as e:
            self.error_label.setText(f"Ошибка при поиске: {e}")
            self.error_label.setStyleSheet("color: red;")

    def refresh_table(self):
        self.model.select()  # Перезагружаем данные из базы данных

    def save_changes(self):
        if self.model.submitAll():  # Пробуем сохранить изменения
            print("Изменения сохранены!")
        else:
            print("Ошибка сохранения:", self.model.lastError().text())
            self.model.revertAll()  # Откатываем изменения при ошибке
            self.error_label.setText(f'Ошибка сохранения: {self.model.lastError().text()}')

    def delete_selected_row(self):
        index = self.tableView.currentIndex()
        row = index.row()
        self.model.removeRow(row)
