import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-ailves_pagecounter')

def handler(event, context):
    response = table.get_item(Key={'id':'0'})

    # Проверка, существует ли запись
    item = response.get('Item')
    
    if item:
        views = item.get('views', 0)
        views += 1
    else:
        # Если записи нет, устанавливаем views в 1
        views = 1

    print(views)

    response = table.put_item(Item={'id':'0', 'views': views})

    return views
