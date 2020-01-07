### Creating a tag
```bash
./github-cli.sh create-tag mageddo-projects github-cli v1.3 master
```

### Creating a release
```bash
./github-cli.sh create-release mageddo-projects github-cli v1.5 master "some description"
```

### Uploading files to release

```bash
./github-cli.sh upload-files mageddo-projects github-cli 22635823 tmp.zip
```

### Release

```bash
./github-cli.sh release mageddo-projects github-cli v1.0 master "some description" tmp.zip
```
