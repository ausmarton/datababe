#!/usr/bin/env node

/// Firestore data diagnostic tool for DataBabe.
///
/// Scans a family's Firestore data for anomalies: missing fields, orphaned
/// records, broken references, timestamp clustering, and response size
/// estimates. Useful for debugging sync issues and data integrity problems.
///
/// Prerequisites:
///   npm install firebase-admin    (in this directory or project root)
///   gcloud auth application-default login
///
/// Usage:
///   node tools/diagnose_firestore.mjs <familyId> [childId]
///
/// If childId is omitted, the script will list all children in the family.

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const familyId = process.argv[2];
if (!familyId) {
  console.error('Usage: node tools/diagnose_firestore.mjs <familyId> [childId]');
  process.exit(1);
}
const childId = process.argv[3] || null;

initializeApp({
  credential: applicationDefault(),
  projectId: 'data-babe',
});
const db = getFirestore();

async function diagnose() {
  console.log('=== FIRESTORE DATA DIAGNOSTIC ===');
  console.log(`Family: ${familyId}`);
  if (childId) console.log(`Child:  ${childId}`);
  console.log();

  // 1. Family document
  console.log('--- Family Document ---');
  const familyDoc = await db.collection('families').doc(familyId).get();
  if (familyDoc.exists) {
    const data = familyDoc.data();
    console.log('Fields:', Object.keys(data).sort().join(', '));
    console.log('name:', data.name);
    console.log('memberUids:', data.memberUids);
    console.log('allergenCategories:', data.allergenCategories);
  } else {
    console.log('Family DOES NOT EXIST!');
    process.exit(1);
  }

  // 2. Children
  console.log('\n--- Children ---');
  const childrenSnap = await db.collection(`families/${familyId}/children`).get();
  for (const doc of childrenSnap.docs) {
    const data = doc.data();
    const fields = Object.keys(data).sort();
    console.log(`\n  ${doc.id}:`);
    console.log('    Fields:', fields.join(', '));
    console.log('    name:', data.name);
    console.log('    has modifiedAt:', 'modifiedAt' in data);
    console.log('    has isDeleted:', 'isDeleted' in data);
    for (const [k, v] of Object.entries(data)) {
      const ts = v?.toDate?.();
      if (ts) console.log(`    ${k}:`, ts.toISOString());
    }
  }
  if (childrenSnap.empty) console.log('  (none)');

  // 3. Activity count
  console.log('\n--- Activity Count ---');
  const countSnap = await db.collection(`families/${familyId}/activities`).count().get();
  const totalActivities = countSnap.data().count;
  console.log('Total activities:', totalActivities);

  // 4. Sample activities (first 5)
  console.log('\n--- Sample Activities (first 5) ---');
  const sampleSnap = await db.collection(`families/${familyId}/activities`).limit(5).get();
  for (const doc of sampleSnap.docs) {
    const data = doc.data();
    console.log(`\n  ${doc.id}:`);
    console.log('    Fields:', Object.keys(data).sort().join(', '));
    console.log('    type:', data.type);
    console.log('    childId:', data.childId);
    console.log('    isDeleted:', data.isDeleted, `(${typeof data.isDeleted})`);
    const st = data.startTime?.toDate?.();
    console.log('    startTime:', st ? st.toISOString() : data.startTime);
    const ca = data.createdAt?.toDate?.();
    console.log('    createdAt:', ca ? ca.toISOString() : data.createdAt);
    const ma = data.modifiedAt?.toDate?.();
    console.log('    modifiedAt:', ma ? ma.toISOString() : data.modifiedAt);
    console.log('    familyId in doc?', 'familyId' in data);
  }

  // 5. Full activity scan for anomalies
  console.log('\n--- Full Activity Scan ---');
  const allActivities = await db.collection(`families/${familyId}/activities`).get();
  let missingChildId = 0;
  let missingIsDeleted = 0;
  let deletedTrue = 0;
  let missingStartTime = 0;
  let missingModifiedAt = 0;
  let missingCreatedAt = 0;
  let createdEqualsModified = 0;
  const childIdSet = new Set();
  const distinctCreatedAt = new Set();
  const distinctModifiedAt = new Set();

  for (const doc of allActivities.docs) {
    const data = doc.data();
    childIdSet.add(data.childId);

    if (!data.childId) missingChildId++;
    if (!('isDeleted' in data)) missingIsDeleted++;
    if (data.isDeleted === true) deletedTrue++;
    if (!data.startTime) missingStartTime++;
    if (!data.modifiedAt) missingModifiedAt++;
    if (!data.createdAt) missingCreatedAt++;

    const caMs = data.createdAt?.toDate?.()?.getTime?.();
    const maMs = data.modifiedAt?.toDate?.()?.getTime?.();
    if (caMs && maMs && caMs === maMs) createdEqualsModified++;

    const ca2 = data.createdAt?.toDate?.();
    if (ca2) distinctCreatedAt.add(ca2.toISOString());
    const ma2 = data.modifiedAt?.toDate?.();
    if (ma2) distinctModifiedAt.add(ma2.toISOString());
  }

  console.log('Total scanned:', allActivities.docs.length);
  console.log('Distinct childIds:', [...childIdSet]);
  console.log('Missing childId:', missingChildId);
  console.log('Missing isDeleted field:', missingIsDeleted);
  console.log('isDeleted === true:', deletedTrue);
  console.log('Missing startTime:', missingStartTime);
  console.log('Missing modifiedAt:', missingModifiedAt);
  console.log('Missing createdAt:', missingCreatedAt);
  console.log('createdAt === modifiedAt:', createdEqualsModified, 'of', allActivities.docs.length);

  // 6. Timestamp analysis
  console.log('\n--- Timestamp Analysis ---');
  console.log('Distinct modifiedAt count:', distinctModifiedAt.size);
  const modifiedAtArr = [...distinctModifiedAt].sort();
  if (modifiedAtArr.length <= 20) {
    console.log('All distinct modifiedAt:', modifiedAtArr);
  } else {
    console.log('modifiedAt first 5:', modifiedAtArr.slice(0, 5));
    console.log('modifiedAt last 5:', modifiedAtArr.slice(-5));
  }

  console.log('Distinct createdAt count:', distinctCreatedAt.size);
  const createdAtArr = [...distinctCreatedAt].sort();
  if (createdAtArr.length <= 20) {
    console.log('All distinct createdAt:', createdAtArr);
  } else {
    console.log('createdAt first 5:', createdAtArr.slice(0, 5));
    console.log('createdAt last 5:', createdAtArr.slice(-5));
  }

  // 7. Response size estimate
  console.log('\n--- Response Size Estimate ---');
  let totalFieldCount = 0;
  for (const doc of sampleSnap.docs) {
    totalFieldCount += Object.keys(doc.data()).length;
  }
  const avgFields = sampleSnap.docs.length > 0
      ? totalFieldCount / sampleSnap.docs.length : 0;
  console.log('Avg fields per doc:', avgFields);
  const estimatedBytes = allActivities.docs.length * avgFields * 50;
  console.log('Estimated response size:', (estimatedBytes / 1024 / 1024).toFixed(2), 'MB');

  // 8. Simulated local format (FirestoreConverter.fromFirestore equivalent)
  if (sampleSnap.docs.length > 0) {
    console.log('\n--- Simulated Local Format (first activity) ---');
    const firstData = sampleSnap.docs[0].data();
    const dateFields = ['startTime', 'endTime', 'createdAt', 'modifiedAt', 'dateOfBirth'];
    const localMap = { ...firstData, familyId: familyId };
    for (const field of dateFields) {
      if (localMap[field]?.toDate) {
        localMap[field] = localMap[field].toDate().toISOString();
      }
    }
    if (!('isDeleted' in localMap)) localMap.isDeleted = false;
    console.log('Converted map:', JSON.stringify(localMap, null, 2));
  }

  // 9. StartTime distribution
  console.log('\n--- StartTime Distribution (most recent 20 days) ---');
  const startDates = {};
  for (const doc of allActivities.docs) {
    const data = doc.data();
    const st2 = data.startTime?.toDate?.();
    if (st2) {
      const key = `${st2.getFullYear()}-${String(st2.getMonth()+1).padStart(2,'0')}-${String(st2.getDate()).padStart(2,'0')}`;
      startDates[key] = (startDates[key] || 0) + 1;
    }
  }
  const sortedDates = Object.entries(startDates).sort((a, b) => b[0].localeCompare(a[0]));
  for (const [date, count] of sortedDates.slice(0, 20)) {
    console.log(`  ${date}: ${count} activities`);
  }
  console.log(`  ... total distinct dates: ${sortedDates.length}`);

  // 10. Other collections summary
  for (const col of ['ingredients', 'recipes', 'targets', 'carers']) {
    const snap = await db.collection(`families/${familyId}/${col}`).get();
    let deleted = 0;
    let missingMod = 0;
    let missingDel = 0;
    for (const doc of snap.docs) {
      const d = doc.data();
      if (d.isDeleted === true) deleted++;
      if (!d.modifiedAt) missingMod++;
      if (!('isDeleted' in d)) missingDel++;
    }
    console.log(`\n--- ${col} ---`);
    console.log(`  Total: ${snap.docs.length}, deleted: ${deleted}, missing modifiedAt: ${missingMod}, missing isDeleted: ${missingDel}`);
  }
}

diagnose().catch(console.error);
