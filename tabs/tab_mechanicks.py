import os
from PyQt6.QtWidgets import QWidget, QHeaderView
from PyQt6.uic import loadUi
from PyQt6.QtSql import QSqlTableModel


class MechanicksTab(QWidget):
    def __init__(self, db, admin_id: int):
        super().__init__()
        ui_path = os.path.join(os.path.dirname(__file__), '..', 'ui', 'tab_mechanicks.ui')
        loadUi(ui_path, self)

        self.qt_db = db

        self.admin_id = admin_id

        self.model = QSqlTableModel(self, self.qt_db)
        self.model.setTable('mechanics')  # Название таблицы в БД

        self.save_btn.clicked.connect(self.save_changes)
        self.refresh_btn.clicked.connect(self.refresh_table)
        self.delete_btn.clicked.connect(self.delete_selected_row)

        # Привязать модель к TableView
        self.tableView.setModel(self.model)
        self.tableView.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.model.setEditStrategy(QSqlTableModel.EditStrategy.OnManualSubmit)
        # Разрешить сортировку по столбцу
        self.tableView.setSortingEnabled(True)
        # Показывать стрелку направления сортировки
        self.tableView.horizontalHeader().setSortIndicatorShown(True)
        self.refresh_table()

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
        first_column_index = self.model.index(row, 0)
        value = self.model.data(first_column_index)

        if int(value) == self.admin_id:
            self.error_label.setText(f'Нельзя удалить себя!')
            return
        self.model.removeRow(row)
