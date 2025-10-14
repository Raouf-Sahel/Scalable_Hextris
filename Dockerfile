# Use a small and fast base image
FROM nginx:alpine

# Set the working directory inside the container
WORKDIR /usr/share/nginx/html

# Remove the default nginx static files
RUN rm -rf ./*

# Copy the Hextris game files into the nginx html folder
COPY . .

# Expose the default HTTP port
EXPOSE 80

# Nginx runs in the foreground by default in this image to always have the container active.
CMD ["nginx", "-g", "daemon off;"]

