# Django Application Logging with Grafana Integration
### A Technical Guide

**Author:** Paul (@pappupaul)  
**Created:** September 1, 2025 02:59:46 UTC  
**Last Updated:** August 31, 2025 23:41:41 UTC

---

## Table of Contents

1. Introduction
2. Django Logging Configuration
3. Request & Response Logging
4. Grafana Integration
5. Dashboard Creation
6. Troubleshooting

---

## 1. Introduction

This document provides a comprehensive guide for implementing logging in Django applications and visualizing the logs using Grafana. We'll cover the entire pipeline from Django's logging configuration to creating Grafana dashboards.

### Prerequisites
- Django application
- Docker and Docker Compose
- Basic understanding of logging concepts

---

## 2. Django Logging Configuration

### 2.1 Basic Setup

Add the following to your Django `settings.py`:

```python
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{asctime} {levelname} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/app/logs/django_requests.log',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django.request': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': True,
        },
        'requestlogs': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
```

### 2.2 Directory Structure

```
your-django-project/
├── logs/
│   └── django_requests.log
├── manage.py
└── your_project/
    ├── settings.py
    └── middleware.py
```

---

## 3. Request & Response Logging

### 3.1 Custom Middleware

Create `middleware.py`:

```python
import json
import logging
from datetime import datetime
from collections import OrderedDict

logger = logging.getLogger('requestlogs')

class RequestResponseLoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Start time of request
        start_time = datetime.now()
        
        # Process request
        response = self.get_response(request)
        
        # Calculate execution time
        execution_time = datetime.now() - start_time

        # Prepare log data
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'method': request.method,
            'path': request.get_full_path(),
            'execution_time': str(execution_time),
            'status_code': response.status_code,
            'user': getattr(request.user, 'username', None),
            'ip_address': request.META.get('REMOTE_ADDR'),
        }

        # Log as JSON
        logger.info(json.dumps(log_data))
        
        return response
```

### 3.2 Add to Django Settings

```python
MIDDLEWARE = [
    # ... other middleware
    'your_project.middleware.RequestResponseLoggingMiddleware',
]
```

---

## 4. Grafana Integration

### 4.1 Docker Compose Setup

```yaml
version: "3.7"
services:
  loki:
    image: grafana/loki:2.9.4
    ports:
      - "3100:3100"
    volumes:
      - loki-data:/loki

  grafana:
    image: grafana/grafana:10.1.1
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki

  promtail:
    image: grafana/promtail:2.9.4
    volumes:
      - ./logs:/var/log:ro
      - ./promtail-config.yaml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

volumes:
  loki-data:
  grafana-data:
```

### 4.2 Promtail Configuration

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: django
    static_configs:
      - targets:
          - localhost
        labels:
          job: django
          env: production
          __path__: /var/log/django_requests.log
```

---

## 5. Dashboard Creation

### 5.1 Configure Loki Data Source

1. Access Grafana at `http://localhost:3000`
2. Go to Configuration → Data Sources
3. Add Loki data source
4. Set URL to `http://loki:3100`
5. Save and Test

### 5.2 Create Dashboard

1. Create New Dashboard
2. Add Panel
3. Example Queries:

```logql
# Request Count by Status
{job="django"}
| json
| status_code != ""
| count_over_time[5m]

# Average Response Time
{job="django"}
| json
| unwrap execution_time
| avg_over_time[5m]
```

---

## 6. Troubleshooting

### Common Issues and Solutions

1. **No Logs in Grafana**
   - Check Promtail container logs
   - Verify log file permissions
   - Confirm Loki connection

2. **Missing Data**
   - Check log format matches parsing
   - Verify timezone settings
   - Check volume mounts

3. **Performance Issues**
   - Monitor log file size
   - Implement log rotation
   - Adjust Loki retention settings

---

## Contact

For questions or support:
- GitHub: [@pappupaul](https://github.com/pappupaul)
- Created: September 1, 2025

---

*End of Document*