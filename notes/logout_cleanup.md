# Logout & Cleanup Checklist

When you are done working with this project, follow these steps to ensure your environment and accounts are secure:

## 1. Logout of GitHub
- Sign out of your GitHub account in your web browser.
- Sign out of your GitHub account in VS Code (use the Accounts menu or Command Palette: `>GitHub: Sign out`).

## 2. Stop Docker Containers
- Stop the Attu and Milvus containers to free resources:

```bash
docker stop attu

docker stop milvus-standalone
```

---

Following these steps will help keep your environment secure and prevent unnecessary resource usage.