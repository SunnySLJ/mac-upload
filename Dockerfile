FROM node:22-bookworm-slim AS node_runtime

FROM python:3.12-slim-bookworm

ARG OPENCLAW_PACKAGE=openclaw@latest
ARG XIAOLONG_UPLOAD_REPO=https://github.com/SunnySLJ/xiaolong-upload.git
ARG OPENCLAW_UPLOAD_REPO=https://github.com/SunnySLJ/openclaw_upload.git

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCLAW_HOME=/root/.openclaw
ENV OPENCLAW_SEED=/opt/openclaw-seed
ENV OPENCLAW_BUNDLE=/opt/openclaw-bundle
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_TRUSTED_HOST=pypi.org pypi.python.org files.pythonhosted.org

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node_runtime /usr/local/bin /usr/local/bin
COPY --from=node_runtime /usr/local/include /usr/local/include
COPY --from=node_runtime /usr/local/lib /usr/local/lib
COPY --from=node_runtime /usr/local/share /usr/local/share

RUN npm config set strict-ssl false \
    && npm install -g "${OPENCLAW_PACKAGE}"

RUN git config --global http.sslVerify false

RUN mkdir -p /root/.config/pip \
    && printf "[global]\ntrusted-host = pypi.org pypi.python.org files.pythonhosted.org\n" > /root/.config/pip/pip.conf

WORKDIR ${OPENCLAW_BUNDLE}

COPY config ./config
COPY scripts ./scripts
COPY skills ./skills
COPY workspace ./workspace
COPY docker ./docker

RUN mkdir -p \
        "${OPENCLAW_SEED}/workspace" \
        "${OPENCLAW_SEED}/skills" \
        "${OPENCLAW_SEED}/cron" \
        "${OPENCLAW_SEED}/memory" \
        "${OPENCLAW_SEED}/memory-md" \
        "${OPENCLAW_SEED}/workspace/inbound_images" \
        "${OPENCLAW_SEED}/workspace/inbound_videos" \
        "${OPENCLAW_SEED}/workspace/logs/auth_qr" \
        "${OPENCLAW_SEED}/workspace/plugins" \
    && cp -a workspace/. "${OPENCLAW_SEED}/workspace/" \
    && cp -a skills/. "${OPENCLAW_SEED}/skills/" \
    && git clone "${XIAOLONG_UPLOAD_REPO}" "${OPENCLAW_SEED}/workspace/xiaolong-upload" \
    && git clone "${OPENCLAW_UPLOAD_REPO}" "${OPENCLAW_SEED}/workspace/openclaw_upload" \
    && if [ -f "${OPENCLAW_SEED}/workspace/xiaolong-upload/requirements.txt" ]; then pip install --no-cache-dir -r "${OPENCLAW_SEED}/workspace/xiaolong-upload/requirements.txt"; fi \
    && if [ -f "${OPENCLAW_SEED}/workspace/openclaw_upload/requirements.txt" ]; then pip install --no-cache-dir -r "${OPENCLAW_SEED}/workspace/openclaw_upload/requirements.txt"; fi \
    && if [ -f "${OPENCLAW_SEED}/workspace/xiaolong-upload/package.json" ]; then cd "${OPENCLAW_SEED}/workspace/xiaolong-upload" && npm install; fi \
    && mkdir -p \
        "${OPENCLAW_SEED}/workspace/openclaw_upload/cookies" \
        "${OPENCLAW_SEED}/workspace/openclaw_upload/logs" \
        "${OPENCLAW_SEED}/workspace/openclaw_upload/published" \
        "${OPENCLAW_SEED}/workspace/openclaw_upload/flash_longxia/output" \
        "${OPENCLAW_SEED}/workspace/openclaw_upload/scripts" \
    && cp -f scripts/cleanup_uploaded_videos.py "${OPENCLAW_SEED}/workspace/openclaw_upload/scripts/cleanup_uploaded_videos.py" \
    && chmod +x "${OPENCLAW_SEED}/workspace/openclaw_upload/scripts/cleanup_uploaded_videos.py" \
    && "${OPENCLAW_BUNDLE}/docker/sync-skills.sh" "${OPENCLAW_SEED}" "${OPENCLAW_BUNDLE}" \
    && chmod +x \
        "${OPENCLAW_BUNDLE}/docker/entrypoint.sh" \
        "${OPENCLAW_BUNDLE}/docker/sync-skills.sh" \
        "${OPENCLAW_BUNDLE}/docker/update-bundled-repos.sh" \
        "${OPENCLAW_BUNDLE}/docker/init-config.py" \
    && ln -s "${OPENCLAW_BUNDLE}/docker/update-bundled-repos.sh" /usr/local/bin/openclaw-update-bundled-repos \
    && ln -s "${OPENCLAW_BUNDLE}/docker/sync-skills.sh" /usr/local/bin/openclaw-sync-skills

VOLUME ["/root/.openclaw"]

ENTRYPOINT ["/opt/openclaw-bundle/docker/entrypoint.sh"]
CMD ["openclaw"]
