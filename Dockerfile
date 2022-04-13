FROM swift:5.5-amazonlinux2

COPY ./CODE /app/CODE

WORKDIR /app

EXPOSE 8080

ENTRYPOINT [ "swift" ]

CMD [ "run", "PennyBOT" ]