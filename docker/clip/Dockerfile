FROM python:3.10-slim

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN pip install --default-timeout=1000 \
    torch torchvision --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt /app/requirements.txt
RUN pip install --default-timeout=1000 -r /app/requirements.txt

COPY server.py /app/server.py

RUN useradd -m clip && mkdir -p /home/clip/.cache && chown -R clip:clip /home/clip/.cache
USER clip

WORKDIR /app

EXPOSE 8501

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8501"]
