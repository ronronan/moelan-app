# `:stable` rather than pinning local dev's 3.44.8: cirruslabs only
# keeps tags for the last few stable releases, and that one had already
# rolled off by the time this was written.
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend .

# Baked in at build time (Flutter web has no runtime config mechanism).
# Override these --build-arg when deploying anywhere other than localhost;
# see README's "Production deployment" section.
ARG API_BASE_URL=http://localhost:8000
ARG KEYCLOAK_ISSUER_URL=http://localhost:8080/realms/moelan
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=KEYCLOAK_ISSUER_URL=${KEYCLOAK_ISSUER_URL}

FROM nginx:1.27-alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY infra/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
