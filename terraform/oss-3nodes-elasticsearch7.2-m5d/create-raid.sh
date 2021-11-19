sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/elastic
sudo mount /dev/md0 /mnt/elastic/
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf