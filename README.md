Install `wd` via `wikibase-cli`:

```bash
npm install -g wikibase-cli@latest
```

Python modules:

```python
pip install h5py sentence-transformers
```

Create a sample text file:

```bash
cat data/*.txt | shuf -n 100 | steps/view.sh > sample.txt
```

Initialize the database:

```bash
seek_vectors build --in sample.txt --out sample.hdf5
```

Query the database:

```bash
seek_vectors query --h5 sample.hdf5 --query "What is the capital of France?" --top-k 20
```