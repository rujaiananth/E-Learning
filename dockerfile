# Use an official Nginx image as base
FROM nginx:alpine

# Copy website content to Nginx HTML directory
COPY . /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]


