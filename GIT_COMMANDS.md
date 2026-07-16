# Git Commands to Publish This Project on GitHub

Run these from inside the `Business_Strategy_Market_Share_Dashboard` folder, after creating an empty repository on GitHub named, for example, `business-strategy-market-share-dashboard`.

```
git init
git add .
git commit -m "Initial commit: Business Strategy and Market Share Performance Dashboard"
git branch -M main
git remote add origin https://github.com/shouryakumawat5-spec/business-strategy-market-share-dashboard.git
git push -u origin main
```

If you make further changes later:

```
git add .
git commit -m "Describe what changed"
git push
```

Optional but recommended before your first push: create a `.gitignore` so you do not accidentally commit local database files if you experiment with a local SQL Server or SQLite instance while testing the scripts.

```
echo "*.db" >> .gitignore
echo "*.bak" >> .gitignore
git add .gitignore
git commit -m "Add gitignore"
```
