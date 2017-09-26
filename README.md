# Logger

Convenience logger used to conditionaly utilize NSLog or new iOS 10 Unified Logging functions. See [Logging Docs](https://developer.apple.com/documentation/os/logging).

## Description

There is a single facade class `Logger` which is allowed to log messages using multiple log levels:

```swift
    public enum Level {
        case `default`
        case info
        case debug
        case error
        case fault
    }
```

And there are predefined log writers:

- `UnifiedLogWriter` prints messages using `os_log`,
- `NSLogWriter` prints messages using `NSLog`,
- `CompositeLogWriter` may compose multiple writers.

## Usage

### Create logger and print debug and info messages

```swift
let logger = Logger()
logger.debug("this is a private debug message: %{private}@", "private parameter")
logger.info("this is a public info message: %{public}@", "public parameter")
```
