mkdir -p ~/moodle-docker && cd ~/moodle-docker
git clone https://github.com/moodle/moodle.git
cd moodle && git checkout MOODLE_404_STABLE && cd ..
mkdir moodledata
nano Dockerfile    # ← 中身貼り付け
nano docker-compose.yml  # ← 中身貼り付け
docker compose up -d --build