import os

def print_project_structure(root_path, indent=''):
    for item in sorted(os.listdir(root_path)):
        item_path = os.path.join(root_path, item)
        if os.path.isdir(item_path):
            print(f"{indent}📁 {item}")
            print_project_structure(item_path, indent + '    ')
        else:
            print(f"{indent}📄 {item}")

if __name__ == "__main__":
    print("Структура проекта:\n")
    current_dir = os.getcwd()  # текущая директория, откуда запущен скрипт
    print_project_structure(current_dir)
