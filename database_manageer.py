import psycopg2
from settings import DB_CONFIG
from PyQt6.QtSql import QSqlDatabase


class DatabaseManager:
    def __init__(self):
        self.connection = None
        self.cursor = None

    def connect(self):
        try:
            self.connection = psycopg2.connect(
                host=DB_CONFIG["host"],
                port=DB_CONFIG["port"],
                database=DB_CONFIG["database"],
                user=DB_CONFIG["user"],
                password=DB_CONFIG["password"]
            )
            self.cursor = self.connection.cursor()
            print("Подключение к базе данных успешно!")

        except psycopg2.Error as e:
            print(f"Ошибка подключения к базе данных: {e}")

        except Exception as e:
            print(f"Другая ошибка: {e}")

    def disconnect(self):
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        print("Соединение с базой данных закрыто.")

    def execute(self, query, params=None):
        try:
            self.cursor.execute(query, params)
            self.connection.commit()
        except psycopg2.Error as e:
            print(f"Ошибка выполнения запроса: {e}")

            self.connection.rollback()
            raise Exception(f"Ошибка выполнения запроса: {e}")

    def fetch_all(self, query, params=None):
        try:
            self.cursor.execute(query, params)
            return self.cursor.fetchall()
        except psycopg2.Error as e:
            print(f"Ошибка получения данных: {e}")
            raise Exception(f"Ошибка получения данных: {e}")

    def fetch_one(self, query, params=None):
        try:
            self.cursor.execute(query, params)
            return self.cursor.fetchone()
        except psycopg2.Error as e:
            print(f"Ошибка получения данных: {e}")
            raise Exception(f"Ошибка получения данных: {e}")

    @staticmethod
    def create_qt_connection():
        db = QSqlDatabase.addDatabase('QPSQL')
        db.setHostName(DB_CONFIG["host"])
        db.setDatabaseName(DB_CONFIG["database"])
        db.setUserName(DB_CONFIG["user"])
        db.setPassword(DB_CONFIG["password"])
        db.setPort(int(DB_CONFIG["port"]))

        if not db.open():
            print("Ошибка подключения через QSqlDatabase:", db.lastError().text())
            return None

        print("Подключение через QSqlDatabase успешно!")
        return db
