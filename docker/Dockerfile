FROM gabrieletassoni/thecore-frontend:18

# Copy the Rails Appplication leaving out the .dockrignored file
ADD dist/* /app/

SHELL ["/bin/bash", "-c"]

CMD ["nginx", "-g", "daemon off;"]

EXPOSE 80
