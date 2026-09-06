#!/usr/bin/env bash
#---------------------------------------------------------------------
# Этап 0: зачистка ресурсов-сирот, не находящихся в Terraform state.
#
# Экономия: ~$4.30/мес (4 KMS CMK + 2 пустые Route53 зоны + 2 секрета).
# Побочно: чинит retention логов Lambda@Edge и убирает висячее
#          NS-делегирование poc-eks (риск subdomain takeover).
#
# Скрипт идемпотентен: шаги, выполненные ранее — вручную или предыдущим
# прогоном, — помечаются SKIP и не останавливают остальные.
#
# По умолчанию РЕЖИМ DRY-RUN — только печатает команды.
# Реальное выполнение:  APPLY=1 ./scripts/stage0-cleanup-orphans.sh
#---------------------------------------------------------------------
set -euo pipefail

APPLY="${APPLY:-0}"
ACCOUNT_EXPECTED="121850521501"
ZONE_MAIN="Z0755312283BG8LDLOJK9"   # ailves2009.com
ZONE_DEV="Z055915317726HOVKNOHE"    # dev.ailves2009.com  (пустая)
ZONE_PUB="Z07277161FDM3QGFJOLH5"    # ailvespub.info      (пустая)

FAILURES=0

# Признаки того, что ресурс уже в нужном состоянии. Это не ошибки: скрипт
# должен переживать повторный запуск и ручные действия, сделанные до него.
ALREADY_DONE_RE='pending deletion|NoSuchHostedZone|HostedZoneNotFound|NoSuchEntity|ResourceNotFoundException|NoSuchQueryLoggingConfig|NoSuchLogGroup|InvalidChangeBatch|but it was not found|does not exist|not found|already .*PAY_PER_REQUEST|Table is already'

run() {
  if [[ "$APPLY" != "1" ]]; then
    echo "[dry-run] $*"
    return 0
  fi

  echo "+ $*" >&2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?

  if (( rc == 0 )); then
    [[ -n "$out" ]] && echo "$out"
    return 0
  fi

  if grep -qiE "$ALREADY_DONE_RE" <<<"$out"; then
    echo "  SKIP: уже выполнено ранее"
    return 0
  fi

  echo "  ОШИБКА: $out" >&2
  FAILURES=$((FAILURES + 1))
  return 0
}

# --- 0. Проверка, что мы в правильном аккаунте -----------------------
acct="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$acct" != "$ACCOUNT_EXPECTED" ]]; then
  echo "ОШИБКА: текущий аккаунт $acct, ожидался $ACCOUNT_EXPECTED" >&2
  exit 1
fi
echo "Аккаунт: $acct   APPLY=$APPLY"
echo

#---------------------------------------------------------------------
# 1. KMS: 3 customer-managed ключа-сироты  →  -$3.00/мес
#---------------------------------------------------------------------
# Биллинг $1/ключ/мес идёт до ФАКТИЧЕСКОГО удаления, а не до постановки
# в очередь. Окно ожидания минимально возможное — 7 дней.
# Отменить можно в любой момент: aws kms cancel-key-deletion --key-id ...
echo "== 1. KMS =="

# us-east-1 / "S3 bucket replication KMS key" — без тегов, не в TF state.
run aws kms schedule-key-deletion --region us-east-1 \
      --key-id 0caa7e48-dfb6-401f-8f1e-fc7057dd5edb --pending-window-in-days 7

# us-east-2 / "dataservices=clgroup-us-east-2" — уже Disabled, чужой проект.
run aws kms schedule-key-deletion --region us-east-2 \
      --key-id 267534fc-6284-4c91-a280-51f207b6379e --pending-window-in-days 7

# us-east-2 / ключ CloudTrail. Проверено: трейл trail-us-east-2 пишет
# в несуществующий бакет (LatestDeliveryError=NoSuchBucket с 2024-02-10),
# зашифрованных этим ключом объектов нет.
run aws kms schedule-key-deletion --region us-east-2 \
      --key-id dc776ae2-5f00-4261-b255-65f8cb189b31 --pending-window-in-days 7

# eu-central-1 / ключ репликации из envs/infra. Терраформом он НЕ управляется:
# state-файла aws-common.tfstate в бакете ailves-2009-terraform-state нет,
# то есть envs/infra полностью вне state. Ни один ресурс на ключ не ссылается.
#
# Второй ключ в eu-central-1 (fffc66df-...) НЕ трогаем: он в state envs/dev
# и уедет сам при terraform apply на Этапе 1.
run aws kms schedule-key-deletion --region eu-central-1 \
      --key-id 5ea0b95d-7b68-4e29-8fa9-ed627319df49 --pending-window-in-days 7
echo

#---------------------------------------------------------------------
# 2. Route 53: 2 пустые зоны  →  -$1.00/мес
#---------------------------------------------------------------------
# В обеих только NS+SOA, они удаляются вместе с зоной автоматически.
echo "== 2. Route 53: пустые зоны =="
run aws route53 delete-hosted-zone --id "$ZONE_DEV"
run aws route53 delete-hosted-zone --id "$ZONE_PUB"
echo

#---------------------------------------------------------------------
# 3. Route 53: висячие записи poc-eks в основной зоне
#---------------------------------------------------------------------
# NS делегирует на зону, которой больше нет  → subdomain takeover.
# CNAME валидировал ACM-сертификат, которого тоже больше нет.
echo "== 3. Route 53: висячие записи poc-eks =="
batch=$(mktemp)
cat > "$batch" <<'JSON'
{
  "Comment": "stage0: remove dangling poc-eks delegation and stale ACM validation record",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "poc-eks.ailves2009.com.",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "ns-128.awsdns-16.com."},
          {"Value": "ns-1799.awsdns-32.co.uk."},
          {"Value": "ns-1261.awsdns-29.org."},
          {"Value": "ns-963.awsdns-56.net."}
        ]
      }
    },
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "_9d80d106f089b4e78fd58355d20766d5.poc-eks.ailves2009.com.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "_2fb44e9ba6fb1a53fd4126bbd202535b.jkddzztszm.acm-validations.aws."}
        ]
      }
    }
  ]
}
JSON
run aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_MAIN" \
      --change-batch "file://$batch"
[[ "$APPLY" == "1" ]] || echo "  (change-batch подготовлен в $batch)"
echo

#---------------------------------------------------------------------
# 3b. Route 53: логирование DNS-запросов
#---------------------------------------------------------------------
# Конфигурация из envs/infra/route53.tf, но, как и KMS-ключ выше, вне
# Terraform state — поэтому убираем здесь, а не через apply.
# Логи DNS-запросов персонального сайта никто не читал, а ingestion
# в CloudWatch стоит $0.50/ГБ (накоплено 3.7 МБ).
#
# Заодно подчищаем три конфигурации, ссылающиеся на зоны, которых больше
# нет: ailves.com (x2) и master.ailves.com.
echo "== 3b. Route 53: query logging =="
# Подстановка процесса, а не пайп: в пайпе цикл ушёл бы в субшелл и счётчик
# FAILURES из него не вернулся бы.
while read -r cfg; do
  [[ -n "$cfg" ]] || continue
  run aws route53 delete-query-logging-config --id "$cfg"
done < <(aws route53 list-query-logging-configs \
           --query 'QueryLoggingConfigs[].Id' --output text 2>/dev/null | tr '\t' '\n')
run aws logs delete-log-group --region us-east-1 --log-group-name "/aws/route53/ailves2009.com"
echo

#---------------------------------------------------------------------
# 4. CloudWatch: retention на логи Lambda@Edge
#---------------------------------------------------------------------
# Lambda@Edge пишет в /aws/lambda/us-east-1.<имя> в КАЖДОМ edge-регионе,
# а не в группу, которую создаёт Terraform. Сейчас там ~128 МБ с
# retention = Never expire. Ставим 7 дней во всех регионах, где группа есть.
echo "== 4. CloudWatch: retention логов Lambda@Edge =="
EDGE_LOG_GROUP="/aws/lambda/us-east-1.update_dynamodb_counter_cfle"
for region in $(aws ec2 describe-regions --region us-east-1 --query 'Regions[].RegionName' --output text); do
  if aws logs describe-log-groups --region "$region" \
       --log-group-name-prefix "$EDGE_LOG_GROUP" \
       --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$EDGE_LOG_GROUP"; then
    run aws logs put-retention-policy --region "$region" \
          --log-group-name "$EDGE_LOG_GROUP" --retention-in-days 7
  fi
done
echo

#---------------------------------------------------------------------
# 5. DynamoDB: таблица блокировок Terraform → on-demand
#---------------------------------------------------------------------
# 1 RCU + 1 WCU provisioned. Сама по себе копейки, но она съедает часть
# free tier 25/25, которую мы хотим отдать таблице счётчика.
echo "== 5. DynamoDB: ailves-tf-state-lock → PAY_PER_REQUEST =="
run aws dynamodb update-table --region us-east-2 \
      --table-name ailves-tf-state-lock --billing-mode PAY_PER_REQUEST
echo

#---------------------------------------------------------------------
# 6. S3: устаревший PDF резюме
#---------------------------------------------------------------------
# В бакете лежат ДВА файла CV: старый с пробелом в имени (443 КБ, фев 2024)
# и актуальный с подчёркиванием (473 КБ, мар 2024). Кнопка "Download CV"
# на сайте ссылается на СТАРЫЙ. Правку ссылки см. в Этапе 3.
echo "== 6. S3: удалить устаревшую копию CV =="
BUCKET="aws-cloud-resume-ailves-dev-source"
STALE_KEY="assets/Aleksandr Ilves_CV_EuroPass.pdf"
while read -r vid; do
  [[ -n "$vid" && "$vid" != "None" ]] || continue
  run aws s3api delete-object --bucket "$BUCKET" --key "$STALE_KEY" --version-id "$vid"
done < <(aws s3api list-object-versions --bucket "$BUCKET" --prefix "$STALE_KEY" \
           --query '[Versions[].VersionId, DeleteMarkers[].VersionId][]' \
           --output text 2>/dev/null | tr '\t' '\n')
echo

#---------------------------------------------------------------------
# 6a. S3: видео-резюме на 246 МБ
#---------------------------------------------------------------------
# 246 МБ — это 96% содержимого бакета. На S3 это копейки, но каждый просмотр
# через CloudFront — это 246 МБ исходящего трафика: сотня просмотров ≈ $2,
# то есть дороже всей остальной инфраструктуры вместе взятой.
#
# ВЫПОЛНЯТЬ ТОЛЬКО ПОСЛЕ того, как видео залито на YouTube и ссылка в
# website/index.html заменена, иначе кнопка "Open Video CV" отдаст 403.
# Раскомментируй, когда будешь готов:
#
# aws s3api list-object-versions --bucket aws-cloud-resume-ailves-dev-source \
#   --prefix "assets/Alexander_Ilves_Video_CV.mp4" \
#   --query '[Versions[].VersionId, DeleteMarkers[].VersionId][]' --output text \
#   | tr '\t' '\n' | grep -v '^$' | grep -v '^None$' | while read -r vid; do
#       aws s3api delete-object --bucket aws-cloud-resume-ailves-dev-source \
#         --key "assets/Alexander_Ilves_Video_CV.mp4" --version-id "$vid"
#     done
echo "== 6a. S3: видео 246 МБ — см. комментарий в скрипте =="
echo

#---------------------------------------------------------------------
# 6b. Secrets Manager  ->  -$0.80/мес
#---------------------------------------------------------------------
# Секретов два, и оба содержат не секреты:
#   test             — не в Terraform state, последнее обращение 2025-02-06
#   eel-site-secrets — им управляет envs/dev, но обычный terraform destroy
#                      ставит секрет в 30-дневное окно восстановления и всё
#                      это время продолжает брать $0.40/мес
# Поэтому убираем оба здесь и сразу, без окна восстановления. Значения
# ("admin" и "ailves2009.com") переезжают в SSM Parameter Store — см. Этап 1.
echo "== 6b. Secrets Manager =="
for secret in test eel-site-secrets; do
  run aws secretsmanager delete-secret --region us-east-2 \
        --secret-id "$secret" --force-delete-without-recovery
done
echo

#---------------------------------------------------------------------
# 7. CloudTrail: сломанный трейл
#---------------------------------------------------------------------
# trail-us-east-2 пишет в бакет aws-cloudtrail-logs-121850521501-4a34acff,
# которого не существует. Последняя успешная доставка: 2024-02-10.
# Аудит-логов в аккаунте нет 2.5 года.
# Вариантов два — раскомментируй нужный:
#   а) удалить трейл (он всё равно ничего не пишет):
# run aws cloudtrail delete-trail --region us-east-2 --name trail-us-east-2
#   б) создать бакет заново и починить логирование — тогда появится
#      расход на S3 за хранение. Для персонального аккаунта хватает
#      бесплатной 90-дневной истории CloudTrail Event history.
echo "== 7. CloudTrail: трейл сломан, решение за тобой (см. комментарий в скрипте) =="
echo

rm -f "$batch"

if [[ "$APPLY" != "1" ]]; then
  echo "Это был DRY-RUN. Для выполнения: APPLY=1 $0"
  exit 0
fi

if (( FAILURES > 0 )); then
  echo "Завершено с ошибками: $FAILURES. Разбери их и запусти скрипт повторно —" >&2
  echo "уже выполненные шаги будут помечены SKIP." >&2
  exit 1
fi

echo "Готово, ошибок нет."
echo
echo "Что проверить:"
echo "  * KMS-ключи уходят в PendingDeletion на 7 дней; счёт перестанет их"
echo "    учитывать только после фактического удаления."
echo "  * Экономия появится в Billing → Cost Explorer через 2-3 дня."
echo "  * Пятый ключ (fffc66df, eu-central-1) удалит terraform apply на Этапе 1."
