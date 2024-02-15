# Use Amazon Linux 2023 as the base image
FROM amazonlinux:2023

# Set the working directory inside the container
WORKDIR /app

# Copy the Bash script into the container
COPY batch.sh /app/

# Make the Bash script executable
RUN chmod +x batch.sh

# Execute the Bash script when the container starts
CMD ["bash", "batch.sh"]
