docker build -t ranger-admin-setup -f Dockerfile.setup .

docker run -it ranger-admin-setup bash

chmod +x setup.sh

./setup.sh

exit

docker cp ranger-admin-setup:/opt/ranger/conf ~/ranger-build/conf
docker cp ranger-admin-setup:/opt/ranger/ews  ~/ranger-build/ews

need these

/conf/*
/ews/*

ranger-admin

ranger-admin-services.sh


cd ~/ranger-build