FROM python:2.7-alpine
MAINTAINER Sam Gabrail
RUN mkdir /app
WORKDIR /app
COPY . .
CMD ["python", "-u", "jenkinsCool.py"]
