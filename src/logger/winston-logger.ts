import { createLogger, transports, format } from "winston";
import config from "../config";
const { LOG_LEVEL } = config;

const logger = createLogger({
  transports: [
    new transports.Console(),
    new transports.File({
      dirname: "./logs",
      filename: "node.log",
      format: format.combine(format.json()),
    }),
  ],
  format: format.combine(
    format.timestamp(),
    format.json(),
    format.printf(({ timestamp, level, message, service }) => {
      return `[${timestamp}] ${service} ${level}: ${message}`;
    })
  ),
  level: LOG_LEVEL,
  handleExceptions: true,
  handleRejections: true,
  defaultMeta: {
    service: "api",
  },
});

export default logger;
