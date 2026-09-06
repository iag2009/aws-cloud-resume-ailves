# Минимизация расходов AWS + технический review, сентябрь 2026

Аккаунт `121850521501`, сайт https://ailves2009.com/

## Что происходило со счётом

Все цифры сверены с фактическим состоянием аккаунта через AWS CLI, не с кодом.

| Сервис | $/мес | Причина | Как проверено |
|---|---:|---|---|
| KMS | 5.00 | 5 customer-managed CMK × $1 | `kms list-keys` в трёх регионах |
| DynamoDB | 3.48 | 31 RCU / 31 WCU provisioned при free tier 25/25 | `dynamodb describe-table` |
| Route 53 | 1.50 | 3 hosted zone × $0.50, две из них пустые | `route53 list-hosted-zones` |
| Secrets Manager | 1.20 | 2 секрета × $0.40 + вызовы API | `secretsmanager list-secrets` |
| S3 | 0.17 | 7.3 ГБ старых версий (по 3.63 ГБ в двух бакетах) + RTC-репликация | `s3api list-object-versions` |
| CloudFront | 0.04 | реальный трафик | — |
| **Итого** | **11.40** | + налог ≈ **$13.66** | |

Расчёт DynamoDB сходится до цента:
`(31−25) WCU × $0.00065 × 730 ч + (31−25) RCU × $0.00013 × 730 ч = $3.42` плюс хранение.
Таблица при этом содержит 45 записей общим объёмом 993 байта.

Ожидаемый счёт после всех этапов: **~$0.55 до налога, ~$0.66 с налогом**.
Остаётся только неустранимое — $0.50 за hosted zone `ailves2009.com` и копейки
за S3/CloudFront. Экономия ≈ **$156/год, −95%**.

## Состояние Terraform, которое надо учитывать до первого apply

Это выяснилось при разборе и меняет порядок действий.

1. **`envs/dev` живёт в workspace `default`, а не `dev`.**
   State лежит по ключу `aws-cloud-resume-ailves/dev/aws-cloud-resume-ailves.tfstate`,
   то есть по пути workspace по умолчанию. Префиксов `env:/` в бакете нет.

   При этом `envs/dev/Makefile` делает
   `terraform workspace select dev || terraform workspace new dev`.
   `make plan` создаст **пустой** workspace `dev` и запланирует создание всей
   инфраструктуры заново — вторую CloudFront-дистрибуцию, вторую таблицу
   DynamoDB (упадёт по конфликту имени) и так далее.

   **Не пользуйся `make plan` / `make apply`, пока это не исправлено.**
   Команды ниже вызывают terraform напрямую, оставаясь в `default`.

2. **У `envs/infra` нет state вообще.**
   Ключа `aws-common.tfstate` в бакете `ailves-2009-terraform-state` не существует.
   Ресурсы из `envs/infra` в AWS есть (сертификат ACM `9bec6541…`, бакет
   `ailves-2009-logs-us-east-2`, KMS-ключ `5ea0b95d…` в eu-central-1,
   логирование DNS-запросов), но Terraform о них не знает.

   Следствие: правки в `envs/infra/*.tf` сами по себе ничего не удалят —
   соответствующие ресурсы убираются скриптом Этапа 0. И наоборот,
   `terraform apply` в `envs/infra` попытается **создать** уже существующие
   ресурсы и упадёт. Пока не сделан `terraform import`, туда лучше не ходить.

3. **Сертификат ACM никем не управляется.** В state `envs/dev` он присутствует
   только как `data`-источник. Продлевается автоматически по DNS-валидации
   (CNAME в зоне на месте), так что это не срочно, но знать стоит.

4. **State записан Terraform 1.6.6, локально стоит 1.15.5.** Первый же apply
   обновит формат state необратимо. Перед этим стоит скопировать текущий
   state-файл себе.

## Порядок применения

### Этап 0 — ресурсы вне Terraform (−$4.30/мес)

```sh
./scripts/stage0-cleanup-orphans.sh            # dry-run, только печатает
APPLY=1 ./scripts/stage0-cleanup-orphans.sh    # выполнение
```

Что делает: снимает 4 KMS-ключа-сироты, удаляет 2 пустые hosted zone, убирает
висячее NS-делегирование `poc-eks`, выключает логирование DNS-запросов, ставит
retention на логи Lambda@Edge в восьми регионах, переводит таблицу блокировок
Terraform на on-demand, удаляет оба секрета и устаревшую копию CV.

Отдельно, по твоему решению, в скрипте закомментированы: удаление видео на
246 МБ (после заливки на YouTube) и судьба сломанного трейла CloudTrail.

Скрипт **идемпотентен**: шаг, выполненный ранее — вручную или предыдущим
прогоном, — печатает `SKIP` и не останавливает остальные. Настоящие ошибки
подсчитываются, скрипт доходит до конца и завершается с кодом 1. Так что после
разбора ошибки его можно просто запустить повторно.

> KMS тарифицирует ключ до **фактического** удаления, а не до постановки
> в очередь. Окно взято минимальное — 7 дней. Отменить: `aws kms cancel-key-deletion`.

#### Про удаляемые зоны

- **`dev.ailves2009.com`** относится к проекту `~/Projects/gitlab/from-slurm`,
  а не к этому репозиторию. Сейчас зона пустая (только NS+SOA) — инфраструктура
  from-slurm, судя по всему, снесена. Удаляем; когда работа над from-slurm
  возобновится, зону нужно будет создать заново и переделегировать от
  родительской `ailves2009.com`.
- **`ailvespub.info`** — домен **не зарегистрирован**: `.info` отвечает
  `NXDOMAIN`, делегирования на серверах реестра (`a0.info.afilias-nst.info`)
  нет, в Route53 Domains числится только `ailves2009.com`. То есть это зона
  для домена, которым никто не владеет: публично к ней никакой резолвер
  обратиться не может, и $0.50/мес платятся буквально ни за что. Удаляем
  без последствий.

### Этап 1 и 2 — Terraform (−$6.30/мес)

```sh
cd envs/dev
terraform workspace show          # должно быть: default
terraform init -upgrade           # провайдер поднят с 5.32.1 до ~> 5.100
terraform plan -var-file=inputs.dev.tfvars.json -out=tfplan
terraform show tfplan | less      # прочитать целиком перед apply
terraform apply tfplan
```

Что должно быть в плане:

| Действие | Ресурс | Комментарий |
|---|---|---|
| destroy | `module.replica_bucket.*` | бакет-реплика, 3.6 ГБ. `force_destroy = true`, содержимое удаляется. **Необратимо** |
| destroy | `aws_kms_key.replica` | `fffc66df…`, 7-дневное окно |
| destroy | `aws_s3_bucket_replication_configuration.this` | 4 правила с RTC и метриками |
| destroy | `aws_iam_role/policy/policy_attachment.replication` | |
| destroy | `aws_secretsmanager_secret*`, `random_pet.this` | если Этап 0 уже отработал, ресурсов в AWS не будет — Terraform это переживёт |
| destroy | `aws_cloudwatch_log_group.cfle` | группа всегда была пустой, см. ниже |
| create | `module.s3_bucket.aws_s3_bucket_lifecycle_configuration.this` | ротация старых версий |
| create | `aws_ssm_parameter.admin_name` | |
| replace | `aws_ssm_parameter.domain_name` | SecureString → String |
| update | `aws_dynamodb_table.this` | PROVISIONED → PAY_PER_REQUEST, снятие GSI `ViewsIndex` |
| update | `aws_lambda_function.this` / `.cfle` | python3.8 → python3.13, новый код |
| update | `aws_cloudfront_distribution.this` | TLS 1.2, новая версия Lambda@Edge |

Дистрибуция CloudFront раскатывается 5–15 минут. Старые версии Lambda@Edge
какое-то время нельзя удалить, пока не разойдутся реплики по edge-регионам —
это нормально, Terraform их и не трогает.

Проверка после apply:

```sh
curl -s https://ailves2009.com/ -o /dev/null -w '%{http_code}\n'
curl -s https://wwwzmykydj4ad2ki5axcp3luxi0altoz.lambda-url.us-east-2.on.aws/
curl -s https://ailves2009.com/index.html -o /dev/null   # должен увеличить счётчик
```

### Этап 3 — CI/CD

```sh
cd envs/dev
terraform output github_actions_role_arn
```

Значение положить в GitHub → Settings → Secrets and variables → Actions →
**Variables** (не Secrets) как `AWS_ROLE_ARN`. После первого успешного прогона
пайплайна отозвать старый ключ:

```sh
aws iam delete-access-key --user-name github-actions \
  --access-key-id AKIARYXW3M6OW75KA6N6
```

и удалить секреты `AWS_ACCESS_KEY` / `AWS_SECRET_KEY` из репозитория.

## Что было починено в коде

### Счётчик просмотров не работал — три независимые причины

1. `func-cfle.py` инкрементил только при `uri == '/index.html'`, но CloudFront
   применяет `default_root_object` **после** viewer-request: заход на `/`
   приходил в функцию как `/`, а не как `/index.html`, и не считался.
2. `func.py` вообще ничего не увеличивал — обе мутирующие строки закомментированы,
   а при отсутствии записи функция возвращала жёсткое `views = 1`.
3. Элемент `.counter-number` **закомментирован** в `index.html:41`, поэтому
   `document.querySelector` возвращал `null` и `updateCounter()` падал
   с TypeError на каждой загрузке страницы.

Первые два пункта исправлены. Третий — раскомментировать блок в разметке,
это уже к правке контента.

### Остальное

- **Гонка в счётчике.** `get_item` → `+1` → `put_item` теряло просмотры при
  одновременном заходе двух посетителей. Заменено на атомарный
  `UpdateItem ... ADD views :inc` — заодно один вызов DynamoDB вместо четырёх.
- **Падение функции роняло весь сайт.** Необработанное исключение в
  viewer-request Lambda@Edge возвращает посетителю HTTP 503. Недоступность
  DynamoDB означала недоступность сайта. Теперь всё обёрнуто, запрос
  возвращается в любом случае, таймауты вызовов жёсткие.
- **PII.** В DynamoDB складывались сырые IP-адреса посетителей без основания,
  без срока хранения и без единого читателя. Пер-IP счётчик убран.
- **Python 3.8 снят с поддержки** — AWS блокирует обновление таких функций.
  Обе Lambda переведены на python3.13, для чего пришлось поднять провайдер AWS
  с 5.32.1 (январь 2024) до `~> 5.100`.
- **Log group для Lambda@Edge создавалась не та.** Terraform заводил
  `/aws/lambda/update_dynamodb_counter_cfle` с retention 14 дней, а Lambda@Edge
  пишет в `/aws/lambda/us-east-1.<имя>` в каждом edge-регионе. Настоящие группы
  (~128 МБ в 8 регионах) стояли с retention «никогда». Плюс пять `print()`
  на каждый вызов. Ресурс убран, retention ставится скриптом Этапа 0.
- **CORS у Function URL был невалиден:** `allow_credentials = true` вместе
  с `allow_origins = ["*"]` браузер отвергает, а `allow_headers` содержал
  forbidden-заголовки `date` и `keep-alive`. Теперь конкретные origin'ы
  и `allow_credentials = false`.
- **Два `aws_secretsmanager_secret_version` на один `secret_id`** перетирали
  друг друга на каждом apply — значение секрета было недетерминированным.
  Secrets Manager убран целиком: ни `admin_name`, ни `domain_name` секретами
  не являются.
- **`aws_iam_policy_attachment`** для репликации — это *exclusive*-ресурс,
  он отвязывает политику от всех прочих ролей и пользователей. Удалён вместе
  с репликацией; в `lambda.tf` используется правильный
  `aws_iam_role_policy_attachment`.
- **Имя таблицы DynamoDB было захардкожено в обоих `.py`.** Переименование
  `var.project` молча ломало Lambda. Теперь код генерируется из
  `*.py.tftpl` через `templatefile`.
- **TLS 1.1** на дистрибуции → `TLSv1.2_2021`.
- **Кнопка «Download CV» вела на устаревшее резюме.** В бакете лежали два PDF:
  `Aleksandr Ilves_CV_EuroPass.pdf` (с пробелом, февраль 2024) и
  `Aleksandr_Ilves_CV_EuroPass.pdf` (март 2024). Разметка ссылалась на первый.
- **Ключ IAM `github-actions` выпущен 2022-02-12 и не ротировался.**
  Заменён на OIDC (`envs/dev/github_oidc.tf`).
- **Пайплайн не сбрасывал кэш CloudFront** — изменения не доезжали до
  посетителей до суток (`max_ttl = 86400`). Добавлена инвалидация и `--delete`.
- **Опечатка в `.gitignore`:** `**/website/assetss/*.mp4` (три «s»). Правило
  никогда не срабатывало, видео на 246 МБ уехало в репозиторий — `.git`
  весит 498 МБ.
- **`.gitlab-ci.yml`** был шаблоном-заглушкой: `sleep 60` вместо тестов,
  `export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID`. Заменён на fmt/validate/plan.
- **`unpkg.com/swiper/...` без версии** — мажорный релиз ломает страницу молча.
  Запинено на 14.2.0 (то, что unpkg отдаёт сейчас, — поведение не изменилось).

## Что осталось и требует твоего решения

- **CloudTrail не работает с 2024-02-10.** Трейл `trail-us-east-2` пишет в
  бакет `aws-cloudtrail-logs-121850521501-4a34acff`, которого нет
  (`LatestDeliveryError: NoSuchBucket`). Аудит-логов в аккаунте нет 2.5 года.
  Либо удалить трейл, либо пересоздать бакет — см. раздел 7 скрипта.
- **Swiper на странице мёртв.** `<div class="swiper-container">` оборачивает
  всю страницу, элементов `swiper-slide` внутри нет, все опции в `index.js`
  закомментированы. Плюс с версии 8 Swiper ждёт класс `swiper`, а не
  `swiper-container`, так что его CSS (`display: flex` на `.swiper-wrapper`)
  просто не применяется. Библиотеку стоит выпилить целиком — это минус два
  сторонних запроса на каждую загрузку.
- **`envs/infra` без state.** Либо сделать `terraform import` существующих
  ресурсов, либо признать директорию нерабочей и удалить.
- **`envs/dev/Makefile` уводит в несуществующий workspace** (см. выше).
- **`envs/tst/**` содержит закоммиченные `terraform.tfstate`** — сейчас они
  под `.gitignore`, но в истории git остались. Стоит проверить на секреты.
- **Мёртвый код:** `envs/dev/ecr.tf` и `envs/infra/beanstalk.tf` закомментированы
  целиком, `envs/dev/outputs.tf` пуст (выводы живут в `cloudfront.tf`).
- **Хардкод account ID `121850521501`** в дефолтах `variables.tf`.
- **`.git` весит 498 МБ** из-за видео. Чистится только перезаписью истории
  (`git filter-repo`) с force-push в оба remote — операция разрушительная,
  делать осознанно.
