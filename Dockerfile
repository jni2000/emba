FROM kalilinux/kali-rolling

COPY ./installer.sh /

WORKDIR /

# docker build needs buildkit enabled
RUN --mount=type=bind,target=/installer,source=./installer \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install wget kmod procps sudo dialog apt curl git 7zip && \
    yes | /installer.sh -s -D && \
    ulimit -c 0 && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Microsoft SQL Server ODBC Driver 18
# ------------------------------------------------------------

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        unixodbc \
        libodbc2 \
        libgssapi-krb5-2; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg; \
    chmod 0644 /etc/apt/keyrings/microsoft.gpg; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/microsoft-prod.list; \
    apt-get update; \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        msodbcsql18; \
    odbcinst -q -d -n "ODBC Driver 18 for SQL Server"; \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# MSSQL compatibility shim v0.3.6
# ------------------------------------------------------------

ARG CVE_MSSQL_SHIM_REF=main

RUN set -eux; \
    test -x /external/emba_venv/bin/python; \
    git clone \
        https://github.com/jni2000/cve_bin_tool_mssql_shim.git \
        /opt/cve_bin_tool_mssql_shim; \
    git -C /opt/cve_bin_tool_mssql_shim \
        checkout "${CVE_MSSQL_SHIM_REF}"; \
    /external/emba_venv/bin/python -m pip install \
        /opt/cve_bin_tool_mssql_shim; \
    /external/emba_venv/bin/python -c \
        "import pyodbc; from cve_bin_tool.cli import main; print('Imports OK')"; \
    /external/emba_venv/bin/cve-bin-tool-mssql --shim-version

# ------------------------------------------------------------
# Make the existing EMBA Python environment available
# ------------------------------------------------------------

ENV PATH="/external/emba_venv/bin:${PATH}"

# NEW: Verify scanner and shim
RUN set -eux; \
    command -v cve-bin-tool-mssql; \
    python -c "from cve_bin_tool.cli import main"; \
    cve-bin-tool-mssql --shim-version

WORKDIR /emba

# nosemgrep
ENTRYPOINT [ "/bin/bash" ]

