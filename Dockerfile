FROM node:11-alpine as base
WORKDIR /app
COPY . .
RUN npm set progress=false && npm config set depth 0 && npm cache clean --force  && npm config set unsafe-perm true && npm i npm@latest -g && npm install --quiet && npm audit fix && npm install -g @angular/cli@latest


FROM node:11-alpine as dev-base
WORKDIR /app
COPY --from=base /app/ ./
ARG APPLICATION_ENV="development"
ARG FRONTEND_URL="https://dev.frontend.com"
ENV APPLICATION_ENV=${APPLICATION_ENV} FRONTEND_URL=${FRONTEND_URL}
RUN npm run build


FROM node:11-alpine as prod-base
WORKDIR /app
COPY --from=base /app/ ./
ARG APPLICATION_ENV="production"
ARG FRONTEND_URL="https://frontend.com"
ENV APPLICATION_ENV=${APPLICATION_ENV} FRONTEND_URL=${FRONTEND_URL}
RUN npm run build



## Development image
FROM nginx:alpine as dev
WORKDIR /usr/share/nginx/html
COPY --from=dev-base /app/dist/frontend/ .
COPY --from=dev-base /app/coverage/ coverage
COPY --from=dev-base /app/documentation/ documentation
COPY nginx/default.conf /etc/nginx/nginx.conf
RUN apk -U add ca-certificates tzdata --no-cache
EXPOSE 8080/tcp
LABEL maintainer="Hitesh Narendra Dhruna" \
    com.frontend.description="Frontend Website" \
    com.frontend.env="development"
CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]


## Production image
FROM nginx:alpine as prod
WORKDIR /usr/share/nginx/html
COPY --from=prod-base /app/dist/frontend/ .
COPY nginx/default.conf /etc/nginx/nginx.conf
RUN apk -U add ca-certificates tzdata --no-cache
EXPOSE 8080/tcp
LABEL maintainer="Hitesh Narendra Dhruna" \
    com.frontend.description="Frontend Website" \
    com.frontend.env="production"
CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]


# Pure NGINX Image
FROM scratch as final
WORKDIR /usr/share/nginx/html
COPY --from=prod /etc/passwd /etc/group /etc/
COPY --from=prod /usr/share/nginx/html/ /usr/share/nginx/html/
COPY --from=prod /usr/sbin/nginx /usr/sbin/nginx
COPY --from=prod /etc/nginx/ /etc/nginx/
COPY --from=prod /var/run/ /var/run/
COPY --from=prod /usr/lib/libpcre.* /usr/lib/
COPY --from=prod /var/log/nginx/ /var/log/nginx/
COPY --from=prod /var/cache/nginx/ /var/cache/nginx/
COPY --from=prod /lib/*.so.*  /lib/
EXPOSE 8080/tcp
CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf", "-g", "daemon off;"]
