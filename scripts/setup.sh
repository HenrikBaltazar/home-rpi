#!/bin/bash

echo "=== Detectando discos externos (sdX) ==="
echo
lsblk -d -o NAME,SIZE,MODEL | grep -E "^sd"
echo

read -p "Digite o disco externo para formatar (ex: sdb): " DISK

# Validação
if [ ! -e "/dev/$DISK" ]; then
    echo "Erro: /dev/$DISK não existe."
    exit 1
fi

echo
echo "⚠️  ATENÇÃO: TODOS OS DADOS EM /dev/$DISK SERÃO PERMANENTEMENTE APAGADOS"
echo "⚠️  Isso inclui TODAS as partições: /dev/${DISK}1, /dev/${DISK}2, etc."
echo
read -p "Digite EXACTAMENTE 'FORMATAR' para confirmar: " CONFIRM

if [ "$CONFIRM" != "FORMATAR" ]; then
    echo "Cancelado pelo usuário."
    exit 0
fi

echo "=== Desmontando partições existentes ==="
sudo umount /dev/${DISK}* 2>/dev/null

echo "=== Apagando tabela de partições ==="
sudo wipefs -a /dev/$DISK
sudo dd if=/dev/zero of=/dev/$DISK bs=1M count=10 status=progress

echo "=== Criando nova tabela GPT ==="
sudo parted -s /dev/$DISK mklabel gpt

echo "=== Criando partição única ocupando 100% do disco ==="
sudo parted -s /dev/$DISK mkpart primary ext4 0% 100%

sleep 2  # dá tempo do kernel atualizar a partição

PART="/dev/${DISK}1"

echo "=== Formatando como EXT4 ==="
sudo mkfs.ext4 -F "$PART"

echo "=== Criando ponto de montagem /srv/media ==="
sudo mkdir -p /srv/media

echo "=== Montando $PART em /srv/media ==="
sudo mount "$PART" /srv/media

echo "=== Obtendo UUID ==="
UUID=$(blkid -s UUID -o value "$PART")

echo "=== Gravando /etc/fstab ==="
echo "UUID=$UUID  /srv/media  ext4  defaults  0  2" | sudo tee -a /etc/fstab >/dev/null

echo
echo "=== Processo concluído com sucesso ==="
echo "Disco formatado: /dev/$DISK"
echo "Partição criada: $PART"
echo "Montado em: /srv/media"
echo "UUID: $UUID"
echo

