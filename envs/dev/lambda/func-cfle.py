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
    request = event['Records'][0]['cf']['request']
    client_ip = request['clientIp']  # Получаем IP-адрес клиента

    # Увеличиваем счетчик просмотров только для GET-запросов к index.html
    if request['method'] == 'GET' and request['uri'] == '/index.html':
        # Увеличиваем общий счетчик просмотров
        response = table.get_item(Key={'id': 'total'})
        item = response.get('Item')
        if item:
            total_views = item.get('views', 0)
            total_views += 1
        else:
            total_views = 1
        table.put_item(Item={'id': 'total', 'views': total_views})

        # Увеличиваем счетчик просмотров для данного IP
        response = table.get_item(Key={'id': client_ip})
        item = response.get('Item')
        if item:
            ip_views = item.get('views', 0)
            ip_views += 1
        else:
            ip_views = 1
        table.put_item(Item={'id': client_ip, 'views': ip_views})

    return request
