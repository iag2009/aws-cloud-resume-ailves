import json
import boto3

# Создайте сессию с указанием региона
session = boto3.Session(
    region_name="us-east-2"  # Укажите регион таблицы DynamoDB
)

# Используйте эту сессию для создания ресурса DynamoDB
dynamodb = session.resource('dynamodb')

table = dynamodb.Table('cloud-resume-ailves_pagecounter')

def handler(event, context):
    response = table.get_item(Key={'id':'0'})

    # Проверка, существует ли запись
    item = response.get('Item')
    
    if item:
        views = item.get('views', 0)
        # views += 1
    else:
        # Если записи нет, устанавливаем views в 1
        views = 1

    print(views)

    response = table.put_item(Item={'id':'0', 'views': views})

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Credentials': True,
            'Access-Control-Allow-Methods': 'GET'  # Разрешаем только GET запросы
        },
        'body': json.dumps({
            'views': int(views)  # Преобразуем views в int перед сериализацией
        })
    }