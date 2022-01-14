sudo apt update
sudo apt install default-jdk maven python -y
java --version

git clone http://github.com/RediSearch/YCSB.git --branch commerce-workload
cd YCSB
mvn -pl site.ycsb:redisjson2-binding -am clean package
