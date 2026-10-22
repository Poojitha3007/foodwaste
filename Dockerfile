FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

RUN echo "Food Waste Tracking and Redistribution Portal" \
    > /usr/share/nginx/html/project.txt

EXPOSE 80
