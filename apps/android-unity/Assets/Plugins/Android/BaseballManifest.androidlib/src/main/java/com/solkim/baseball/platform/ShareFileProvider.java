package com.solkim.baseball.platform;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/** Read-only provider restricted to cache/share. No external storage permission is used. */
public final class ShareFileProvider extends ContentProvider {
    private File shareRoot;

    @Override
    public boolean onCreate() {
        try {
            shareRoot = new File(getContext().getCacheDir(), "share").getCanonicalFile();
            return shareRoot.exists() || shareRoot.mkdirs();
        } catch (IOException exception) {
            return false;
        }
    }

    @Override
    public String getType(Uri uri) {
        resolveFile(uri);
        return "image/png";
    }

    @Override
    public Cursor query(
            Uri uri,
            String[] projection,
            String selection,
            String[] selectionArgs,
            String sortOrder) {
        File file = resolveFile(uri);
        String[] columns = projection == null
                ? new String[] { OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE }
                : projection;
        MatrixCursor cursor = new MatrixCursor(columns, 1);
        MatrixCursor.RowBuilder row = cursor.newRow();
        for (String column : columns) {
            if (OpenableColumns.DISPLAY_NAME.equals(column)) {
                row.add(file.getName());
            } else if (OpenableColumns.SIZE.equals(column)) {
                row.add(file.length());
            } else {
                row.add(null);
            }
        }
        return cursor;
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Share files are read-only.");
        File file = resolveFile(uri);
        if (!file.isFile()) throw new FileNotFoundException("Share file does not exist.");
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        throw new UnsupportedOperationException("Share files are read-only.");
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("Share files are read-only.");
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("Share files are read-only.");
    }

    private File resolveFile(Uri uri) {
        if (shareRoot == null || uri == null || uri.getPathSegments().size() != 1) {
            throw new SecurityException("Invalid share URI.");
        }
        try {
            File candidate = new File(shareRoot, uri.getLastPathSegment()).getCanonicalFile();
            String rootPrefix = shareRoot.getPath() + File.separator;
            if (!candidate.getPath().startsWith(rootPrefix)) {
                throw new SecurityException("Share URI escaped the cache directory.");
            }
            return candidate;
        } catch (IOException exception) {
            throw new SecurityException("Unable to resolve share URI.", exception);
        }
    }
}
