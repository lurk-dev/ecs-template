# ECS-TEMPLATE

A secure, ECS-based Roblox game built with JECS and Planck scheduler.

## 📚 Documentation

- **[Development Guide](./docs/GENERIC_INFO.md)** - Complete ECS development reference
- **[Network System](./docs/NETWORK_USAGE.md)** - Secure networking with middleware
- **[Quick Reference](./docs/README.md)** - Documentation overview

## 🚀 Getting Started

### Development Setup

To build the place from scratch, use:

```bash
rojo build -o "ecs-template.rbxlx"
```

Next, open `ecs-template.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

### Architecture Overview

- **ECS System**: JECS entity-component-system with Planck scheduler
- **Security**: Three-config system (server/client/shared) with server-authoritative design
- **Networking**: Secure middleware-based networking with Promise library integration, rate limiting and validation
- **Debugging**: Configurable debug system with Jabby integration

For detailed information, see the [documentation](./docs/).

## 🛠️ Project Structure

```
src/
├── client/           # Client-side code
├── server/           # Server-side code
├── shared/           # Shared code and configurations
docs/                 # Complete documentation
```

## Additional Resources

- [Rojo Documentation](https://rojo.space/docs)
- [JECS Documentation](https://github.com/Ukendio/jecs)
- [Planck Scheduler](https://github.com/YetAnotherClown/planck)
