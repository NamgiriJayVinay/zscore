 protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);




        dropDown = findViewById(R.id.dropDown);
        autoCompleteTextView = findViewById(R.id.autoCompleteTextView);
        selectedAppLayout = findViewById(R.id.selectedAppLayout); // Add a container for selected app view
        packageManager = getPackageManager();

        // Retrieve installed apps with package names starting with "com.example.sensors_app-"
        List<ApplicationInfo> sensorApps = getInstalledSensorApps();

        // Create the custom adapter
        appDropdownAdapter = new AppDropdownAdapter(this, sensorApps);

        // Set the adapter to the AutoCompleteTextView
        autoCompleteTextView.setAdapter(appDropdownAdapter);

        // Set the OnItemClickListener to handle the selection
        autoCompleteTextView.setOnItemClickListener((parent, view, position, id) -> {
            // Get the selected ApplicationInfo
            ApplicationInfo selectedApp = appDropdownAdapter.getItem(position);

            // Get the app label (human-readable name) and app icon
            if (selectedApp != null) {
                String appLabel = packageManager.getApplicationLabel(selectedApp).toString();
                Drawable appIcon = packageManager.getApplicationIcon(selectedApp);
                Log.d("SENT","selected app  "+selectedApp+"*****************");

                // Inflate the custom view and set app name and icon
                LayoutInflater inflater = LayoutInflater.from(this);
                View selectedAppView = inflater.inflate(R.layout.selected_app_view, selectedAppLayout, false);

                TextView appNameTextView = selectedAppView.findViewById(R.id.appNameSelected);
                ImageView appIconImageView = selectedAppView.findViewById(R.id.appIconSelected);

                appNameTextView.setText(appLabel);
                appIconImageView.setImageDrawable(appIcon);

                // Clear previous views if any and add the new selected app view
                selectedAppLayout.removeAllViews();
                selectedAppLayout.addView(selectedAppView);

                autoCompleteTextView.setText(appLabel);

                // Optionally, show a toast or do something else with the selected app
                Toast.makeText(MainActivity.this, "Selected App: " + appLabel, Toast.LENGTH_SHORT).show();
            }
        });






















package com.example.zscore;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.opencsv.CSVReader;

import org.apache.commons.math3.stat.descriptive.DescriptiveStatistics;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class MainActivity extends AppCompatActivity {

    private static final int PICK_CSV_FILE = 1;
    private List<String> columnNames;
    private List<CheckBox> checkBoxes;
    private Uri csvFileUri;
    private LinearLayout columnsContainer;
    private LinearLayout resultsContainer;
    private Button analyzeButton;
    private CheckBox selectAllCheckbox;
    private CheckBox deselectAllCheckbox;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Button uploadButton = findViewById(R.id.uploadButton);
        columnsContainer = findViewById(R.id.columnsContainer);
        resultsContainer = findViewById(R.id.resultsContainer);
        analyzeButton = findViewById(R.id.analyzeButton);
        selectAllCheckbox = findViewById(R.id.selectAllCheckbox);
        deselectAllCheckbox = findViewById(R.id.deselectAllCheckbox);

        uploadButton.setOnClickListener(v -> openFilePicker());

        analyzeButton.setOnClickListener(v -> analyzeCsv());

        selectAllCheckbox.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                deselectAllCheckbox.setChecked(false);
                for (CheckBox checkBox : checkBoxes) {
                    checkBox.setChecked(true);
                }
            }
        });

        deselectAllCheckbox.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                selectAllCheckbox.setChecked(false);
                for (CheckBox checkBox : checkBoxes) {
                    checkBox.setChecked(false);
                }
            }
        });
    }

    private void openFilePicker() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.setType("text/csv");
        startActivityForResult(Intent.createChooser(intent, "Select CSV File"), PICK_CSV_FILE);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == PICK_CSV_FILE && resultCode == RESULT_OK && data != null) {
            csvFileUri = data.getData();
            loadCsvColumns();
        }
    }

    private void loadCsvColumns() {
        try {
            InputStream inputStream = getContentResolver().openInputStream(csvFileUri);
            CSVReader reader = new CSVReader(new InputStreamReader(inputStream));
            String[] header = reader.readNext();
            if (header != null) {
                columnNames = new ArrayList<>();
                checkBoxes = new ArrayList<>();
                for (String column : header) {
                    columnNames.add(column);
                }
                Collections.sort(columnNames);  // Sort columns alphabetically

                columnsContainer.removeAllViews();
                for (String column : columnNames) {
                    CheckBox checkBox = new CheckBox(this);
                    checkBox.setText(column);
                    columnsContainer.addView(checkBox);
                    checkBoxes.add(checkBox);
                }
                analyzeButton.setVisibility(View.VISIBLE);
            }
            reader.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void analyzeCsv() {
        List<String> selectedColumns = new ArrayList<>();
        for (CheckBox checkBox : checkBoxes) {
            if (checkBox.isChecked()) {
                selectedColumns.add(checkBox.getText().toString());
            }
        }

        if (!selectedColumns.isEmpty()) {
            try {
                InputStream inputStream = getContentResolver().openInputStream(csvFileUri);
                CSVReader reader = new CSVReader(new InputStreamReader(inputStream));
                List<String[]> rows = reader.readAll();
                reader.close();

                List<String> uidsAboveThreshold = performZScoreAnalysis(rows, selectedColumns, 2);

                displayResults(uidsAboveThreshold);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else {
            // Display a message if no columns are selected
            resultsContainer.removeAllViews();
            TextView textView = new TextView(this);
            textView.setText("Please select at least one column to analyze.");
            textView.setTextSize(16);
            textView.setPadding(8, 8, 8, 8);
            resultsContainer.addView(textView);
        }
    }

    private List<String> performZScoreAnalysis(List<String[]> rows, List<String> selectedColumns, double threshold) {
        Set<String> uidsAboveThreshold = new HashSet<>();
        if (rows.isEmpty() || selectedColumns.isEmpty()) {
            return new ArrayList<>(uidsAboveThreshold);
        }

        String[] header = rows.get(0);
        Map<String, Integer> columnIndexMap = new HashMap<>();
        for (int i = 0; i < header.length; i++) {
            if (selectedColumns.contains(header[i])) {
                columnIndexMap.put(header[i], i);
            }
        }

        int uidIndex = -1;
        for (int i = 0; i < header.length; i++) {
            if ("uid".equalsIgnoreCase(header[i])) {
                uidIndex = i;
                break;
            }
        }
        if (uidIndex == -1) {
            return new ArrayList<>(uidsAboveThreshold); // UID column not found
        }

        Map<String, List<Double>> columnData = new HashMap<>();
        for (String column : selectedColumns) {
            columnData.put(column, new ArrayList<>());
        }

        List<String> uids = new ArrayList<>();
        for (int i = 1; i < rows.size(); i++) {
            String[] row = rows.get(i);
            uids.add(row[uidIndex]);
            for (String column : selectedColumns) {
                int index = columnIndexMap.get(column);
                double value = Double.parseDouble(row[index]);
                columnData.get(column).add(value);
            }
        }

        Map<String, List<Double>> zScoresMap = new HashMap<>();
        for (String column : selectedColumns) {
            List<Double> values = columnData.get(column);
            DescriptiveStatistics stats = new DescriptiveStatistics();
            for (double value : values) {
                stats.addValue(value);
            }
            double mean = stats.getMean();
            double stdDev = stats.getStandardDeviation();

            List<Double> zScores = new ArrayList<>();
            for (double value : values) {
                double zScore = (value - mean) / stdDev;
                zScores.add(zScore);
            }
            zScoresMap.put(column, zScores);
        }
        for (int i = 0; i < uids.size(); i++) {
            for (String column : selectedColumns) {
                if (Math.abs(zScoresMap.get(column).get(i)) >= threshold) {
                    uidsAboveThreshold.add(uids.get(i));
                    break;
                }
            }
        }

        return new ArrayList<>(uidsAboveThreshold);
    }

    private void displayResults(List<String> uidsAboveThreshold) {
        resultsContainer.removeAllViews();  // Clear previous results
        for (String uid : uidsAboveThreshold) {
            TextView textView = new TextView(this);
            textView.setText(uid);
            textView.setTextSize(16);
            textView.setPadding(8, 8, 8, 8);
            resultsContainer.addView(textView);
        }
    }
}

