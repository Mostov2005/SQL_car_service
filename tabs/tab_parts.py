import sys
import os
from PyQt6.QtWidgets import QWidget, QApplication, QHeaderView
from PyQt6.uic import loadUi
from PyQt6.QtSql import QSqlTableModel


class PartsTab(QWidget):
    def __init__(self, dbmanager, qt_db):
        super().__init__()
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'tab_parts.ui')
        loadUi(ui_path, self)

        self.qt_db = qt_db
        self.dbmaneger = dbmanager

        self.model = QSqlTableModel(self, self.qt_db)
        self.model.setTable('parts')  # Название таблицы в БД

        self.save_btn.clicked.connect(self.save_changes)
        self.refresh_btn.clicked.connect(self.refresh_table)
        self.delete_btn.clicked.connect(self.delete_selected_row)
        self.search_part_btn.clicked.connect(self.search_part_on_name)

        # Привязать модель к TableView
        self.tableView.setModel(self.model)
        self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.model.setEditStrategy(QSqlTableModel.EditStrategy.OnManualSubmit)
        # Разрешить сортировку по столбцу
        self.tableView.setSortingEnabled(True)
        # Показывать стрелку направления сортировки
        self.tableView.horizontalHeader().setSortIndicatorShown(True)
        self.refresh_table()

    def search_part_on_name(self):
        name = self.part_edit.text().strip()

        if not name:
            # Сброс фильтра и обновление таблицы
            self.model.setFilter("")
            self.model.select()
            self.error_label.setText("Фильтр сброшен. Показаны все детали.")
            self.error_label.setStyleSheet("color: gray;")
            return

        escaped_name = name.replace("'", "''")

        self.model.setFilter(f"part_name = '{escaped_name}'")
        self.model.select()
        self.error_label.setText(f"Показаны детали с именем: {name}")
        self.error_label.setStyleSheet("color: green;")

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
