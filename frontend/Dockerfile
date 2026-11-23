# ==============================================================================
# OISM Frontend Nginx Web Server Dockerfile
# ==============================================================================
FROM nginx:alpine

# Xoa cau hinh mac dinh cua Nginx
RUN rm -f /etc/nginx/conf.d/default.conf

# Sao chep cau hinh Nginx tuy chinh co ho tro Reverse Proxy API
COPY nginx.conf /etc/nginx/nginx.conf

# Sao chep cac tep giao dien nguoi dung vao thu muc goc cua Nginx
COPY index.html /usr/share/nginx/html/index.html
COPY success.mp3 /usr/share/nginx/html/success.mp3

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
