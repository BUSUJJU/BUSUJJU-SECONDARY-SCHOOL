const menuToggle = document.querySelector("#menu-toggle");
const mainNav = document.querySelector("#main-nav");
const searchPanel = document.querySelector("#search-panel");
const searchTrigger = document.querySelector("#search-trigger");
const searchInput = document.querySelector("#site-search");
const searchResults = document.querySelector("#search-results");
const enquiryDialog = document.querySelector("#enquiry-dialog");
const toast = document.querySelector("#toast");

document.querySelector("#current-year").textContent = new Date().getFullYear();

document.querySelector("#announcement-close").addEventListener("click", () => {
  document.querySelector("#announcement").hidden = true;
});

menuToggle.addEventListener("click", () => {
  const isOpen = menuToggle.getAttribute("aria-expanded") === "true";
  menuToggle.setAttribute("aria-expanded", String(!isOpen));
  mainNav.classList.toggle("is-open", !isOpen);
});

mainNav.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => {
    mainNav.classList.remove("is-open");
    menuToggle.setAttribute("aria-expanded", "false");
  });
});

function openSearch() {
  searchPanel.classList.add("is-open");
  searchPanel.setAttribute("aria-hidden", "false");
  document.body.classList.add("no-scroll");
  window.setTimeout(() => searchInput.focus(), 50);
}

function closeSearch() {
  searchPanel.classList.remove("is-open");
  searchPanel.setAttribute("aria-hidden", "true");
  document.body.classList.remove("no-scroll");
  searchTrigger.focus();
}

searchTrigger.addEventListener("click", openSearch);
document.querySelector("#search-close").addEventListener("click", closeSearch);
searchPanel.addEventListener("click", (event) => {
  if (event.target === searchPanel) closeSearch();
});

const searchableSections = [...document.querySelectorAll("main section[id]")].map((section) => ({
  id: section.id,
  title: section.querySelector("h1, h2, h3")?.textContent.replace(/\s+/g, " ").trim() || section.id,
  text: section.innerText.toLowerCase()
}));

searchInput.addEventListener("input", () => {
  const query = searchInput.value.trim().toLowerCase();
  searchResults.replaceChildren();
  if (query.length < 2) return;

  const matches = searchableSections.filter((section) => section.text.includes(query) || section.id.includes(query)).slice(0, 6);
  if (!matches.length) {
    const empty = document.createElement("p");
    empty.className = "search-empty";
    empty.textContent = "No matching sections found. Try a different search.";
    searchResults.append(empty);
    return;
  }

  matches.forEach((section) => {
    const link = document.createElement("a");
    link.className = "search-result";
    link.href = `#${section.id}`;
    link.textContent = section.title;
    const description = document.createElement("small");
    description.textContent = `Go to ${section.id.replaceAll("-", " ")}`;
    link.append(description);
    link.addEventListener("click", closeSearch);
    searchResults.append(link);
  });
});

document.querySelector("#search-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const firstResult = searchResults.querySelector("a");
  if (firstResult) firstResult.click();
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && searchPanel.classList.contains("is-open")) closeSearch();
});

function openEnquiry(topic) {
  if (topic) {
    const select = enquiryDialog.querySelector('select[name="interest"]');
    const option = [...select.options].find((item) => item.textContent.toLowerCase().includes(topic));
    if (option) select.value = option.value;
  }
  enquiryDialog.showModal();
  document.body.classList.add("no-scroll");
  enquiryDialog.querySelector('input[name="name"]').focus();
}

function closeEnquiry() {
  enquiryDialog.close();
  document.body.classList.remove("no-scroll");
}

document.querySelector("#open-admissions").addEventListener("click", () => openEnquiry("admissions"));
document.querySelector("#open-visit").addEventListener("click", () => openEnquiry("visiting"));
document.querySelector("#open-footer-contact").addEventListener("click", () => openEnquiry());
document.querySelector("#faq-contact").addEventListener("click", () => openEnquiry());
document.querySelector("#dialog-close").addEventListener("click", closeEnquiry);
enquiryDialog.addEventListener("click", (event) => {
  if (event.target === enquiryDialog) closeEnquiry();
});
enquiryDialog.addEventListener("close", () => document.body.classList.remove("no-scroll"));

let toastTimer;
function showToast(message) {
  toast.textContent = message;
  toast.classList.add("is-visible");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove("is-visible"), 4500);
}

const schoolContactEmail = "reynoldsemstone@gmail.com";

function handleEmailSubmission(form, feedback, getSubject) {
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const values = Object.fromEntries(new FormData(form));
    const labels = {
      name: "Name",
      email: "Reply email",
      topic: "Topic",
      interest: "Enquiry type",
      message: "Message"
    };
    const body = Object.entries(values)
      .filter(([, value]) => String(value).trim())
      .map(([key, value]) => `${labels[key] || key}: ${value}`)
      .join("\n");
    const draftLink = document.createElement("a");
    draftLink.href = `mailto:${schoolContactEmail}?subject=${encodeURIComponent(getSubject(values))}&body=${encodeURIComponent(body)}`;
    draftLink.textContent = `Open email draft to ${schoolContactEmail}`;
    draftLink.className = "email-draft-link";
    feedback.replaceChildren(
      document.createTextNode("Your email app will open with the message prepared. Review it and select Send. "),
      draftLink
    );
  });
}

handleEmailSubmission(
  document.querySelector("#enquiry-form"),
  document.querySelector("#dialog-feedback"),
  (values) => `Website enquiry: ${values.interest}`
);

handleEmailSubmission(
  document.querySelector("#contact-form"),
  document.querySelector("#form-feedback"),
  (values) => `Website message: ${values.topic}`
);

handleEmailSubmission(
  document.querySelector("#newsletter-form"),
  document.querySelector("#newsletter-feedback"),
  () => "Subscribe to Busujju school updates"
);

const timetableData = {
  S1: [["English", "Mathematics", "Biology", "Geography"], ["Mathematics", "History", "English", "Physics"], ["Chemistry", "English", "Mathematics", "Literature"], ["Biology", "Physics", "History", "Mathematics"], ["Geography", "Chemistry", "English", "Mathematics"]],
  S2: [["Mathematics", "English", "Chemistry", "History"], ["English", "Geography", "Mathematics", "Biology"], ["History", "Chemistry", "English", "Mathematics"], ["Physics", "Biology", "Mathematics", "English"], ["English", "Mathematics", "Geography", "Chemistry"]],
  S3: [["Mathematics", "English", "Biology", "History"], ["English", "Physics", "Mathematics", "Literature"], ["Chemistry", "Geography", "English", "Mathematics"], ["Biology", "Mathematics", "ICT", "English"], ["History", "English", "Geography", "Physics"]],
  S4: [["Mathematics", "English", "Chemistry", "Geography"], ["English", "Physics", "Mathematics", "Biology"], ["History", "Chemistry", "English", "Mathematics"], ["Biology", "Mathematics", "English", "ICT"], ["Geography", "English", "History", "Mathematics"]],
  S5: [["Mathematics", "Biology / Economics", "English Language", "Chemistry / History"], ["Chemistry / Literature", "Mathematics", "Physics / Economics", "Biology / History"], ["English Language", "Biology / Geography", "Mathematics", "Chemistry / Literature"], ["Physics / Economics", "Chemistry / Geography", "English Language", "Mathematics"], ["Mathematics", "Biology / History", "Chemistry / Economics", "Physics / Geography"]],
  S6: [["Mathematics", "Biology / Economics", "English Language", "Chemistry / History"], ["Chemistry / Literature", "Mathematics", "Physics / Economics", "Biology / History"], ["English Language", "Biology / Geography", "Mathematics", "Chemistry / Literature"], ["Physics / Economics", "Chemistry / Geography", "English Language", "Mathematics"], ["Mathematics", "Biology / History", "Chemistry / Economics", "Physics / Geography"]]
};

const saturdayTimetable = {
  S1: [],
  S2: [],
  S3: ["Mathematics", "English", "Integrated Science", "Study period"],
  S4: ["Mathematics", "English", "Integrated Science", "Examination practice"],
  S5: ["Mathematics", "Science / Arts option", "Science / Arts option", "General Paper"],
  S6: ["Mathematics", "Science / Arts option", "Science / Arts option", "General Paper"]
};

const timetableClass = document.querySelector("#timetable-class");
const timetableBody = document.querySelector("#timetable-body");
const timetableCaption = document.querySelector("#timetable-caption");
const schoolDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function renderTimetable() {
  const className = timetableClass.value;
  timetableBody.replaceChildren();
  schoolDays.forEach((day, dayIndex) => {
    const row = document.createElement("tr");
    const dayCell = document.createElement("th");
    dayCell.scope = "row";
    dayCell.textContent = day;
    row.append(dayCell);
    const lessons = day === "Saturday" ? saturdayTimetable[className] : timetableData[className][dayIndex];
    if (day === "Saturday" && lessons.length === 0) {
      const noClassesCell = document.createElement("td");
      noClassesCell.colSpan = 4;
      noClassesCell.className = "no-saturday-classes";
      noClassesCell.textContent = "No Saturday classes";
      row.append(noClassesCell);
      timetableBody.append(row);
      return;
    }
    lessons.forEach((lesson) => {
      const cell = document.createElement("td");
      cell.textContent = lesson;
      row.append(cell);
    });
    timetableBody.append(row);
  });
  const levelNote = className === "S5" || className === "S6"
    ? "Saturday classes continue into the afternoon. Parallel subject blocks are options, not one learner's combination."
    : className === "S3" || className === "S4"
      ? "Saturday classes continue into the afternoon. Confirm subject allocations with the school."
      : "No Saturday classes for this level. Confirm subject allocations with the school.";
  timetableCaption.textContent = `Senior ${className.slice(1)} · Four periods each school day. ${levelNote}`;
}

timetableClass.addEventListener("change", renderTimetable);
renderTimetable();

const portalLogin = document.querySelector("#portal-login");
const portalChoice = document.querySelector("#portal-choice");
const teacherSignup = document.querySelector("#teacher-signup");
const studentDashboard = document.querySelector("#student-dashboard");
const teacherDashboard = document.querySelector("#teacher-dashboard");
const loginFeedback = document.querySelector("#login-feedback");
const portalEntryFeedback = document.querySelector("#portal-entry-feedback");
let currentLoginRole = "student";

async function portalRequest(path, options = {}) {
  let response;
  try {
    response = await fetch(path, {
      credentials: "same-origin",
      ...options,
      headers: { "Content-Type": "application/json", ...options.headers }
    });
  } catch {
    throw new Error("Start the school server and open http://127.0.0.1:8080/ to use student and teacher accounts.");
  }
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new Error("Start the school server and open http://127.0.0.1:8080/ to use student and teacher accounts.");
  }
  if (!response.ok) throw new Error(payload.error || "The request could not be completed.");
  return payload;
}

function showPortalPanel(role) {
  if (!role) {
    showPortalEntry("choice");
    return;
  }
  portalChoice.hidden = true;
  portalLogin.hidden = true;
  teacherSignup.hidden = true;
  studentDashboard.hidden = role !== "student";
  teacherDashboard.hidden = role !== "teacher";
}

function showPortalEntry(view) {
  portalChoice.hidden = view !== "choice";
  portalLogin.hidden = view !== "student-login" && view !== "teacher-login";
  teacherSignup.hidden = view !== "teacher-signup";
  studentDashboard.hidden = true;
  teacherDashboard.hidden = true;
  if (view === "student-login" || view === "teacher-login") {
    currentLoginRole = view === "student-login" ? "student" : "teacher";
    document.querySelector("#portal-login-title").textContent = currentLoginRole === "student" ? "Student sign in" : "Teacher sign in";
    document.querySelector("#portal-login-description").textContent = currentLoginRole === "student"
      ? "Use the school ID or username given to you by your teacher, together with your password."
      : "Sign in with your approved teacher account to manage student accounts and results.";
    document.querySelector("#portal-identity-label").firstChild.textContent = currentLoginRole === "student" ? "School ID or username" : "Teacher username";
    document.querySelector("#portal-identity").placeholder = currentLoginRole === "student" ? "School ID or username" : "Teacher username";
    loginFeedback.textContent = "";
  }
}

document.querySelectorAll("[data-portal-view]").forEach((button) => {
  button.addEventListener("click", () => showPortalEntry(button.dataset.portalView));
});

document.querySelectorAll(".portal-back").forEach((button) => {
  button.addEventListener("click", () => showPortalEntry("choice"));
});

function appendTableRow(tableBody, values) {
  const row = document.createElement("tr");
  values.forEach((value) => {
    const cell = document.createElement("td");
    cell.textContent = value;
    row.append(cell);
  });
  tableBody.append(row);
}

async function loadStudentPortal(user) {
  showPortalPanel("student");
  document.querySelector("#student-welcome").textContent = `${user.name} · Senior ${user.className.slice(1)}`;
  const feedback = document.querySelector("#student-feedback");
  const body = document.querySelector("#student-results-body");
  body.replaceChildren();
  try {
    const { results } = await portalRequest("/api/results");
    if (!results.length) feedback.textContent = "No results have been published to your account yet.";
    else {
      feedback.textContent = `${results.length} result${results.length === 1 ? "" : "s"} available.`;
      results.forEach((result) => appendTableRow(body, [
        result.subject,
        result.assessment,
        String(result.score),
        String(result.outOf),
        new Date(result.createdAt).toLocaleDateString()
      ]));
    }
  } catch (error) {
    feedback.textContent = error.message;
  }
}

async function loadTeacherPortal(user) {
  showPortalPanel("teacher");
  document.querySelector("#teacher-welcome").textContent = user.name;
  const feedback = document.querySelector("#student-create-feedback");
  const studentSelect = document.querySelector("#result-student");
  const studentsBody = document.querySelector("#teacher-students-body");
  studentSelect.replaceChildren(new Option("Select a student", ""));
  studentsBody.replaceChildren();
  try {
    const { students } = await portalRequest("/api/teacher/students");
    students.forEach((student) => {
      studentSelect.add(new Option(`${student.name} · ${student.studentCode} · ${student.className}`, student.id));
      appendTableRow(studentsBody, [student.name, student.username, student.studentCode, student.className]);
    });
    feedback.textContent = students.length ? "" : "No student accounts yet. Create the first account above.";
  } catch (error) {
    feedback.textContent = error.message;
  }
  const requestsPanel = document.querySelector("#teacher-requests");
  const requestsList = document.querySelector("#teacher-requests-list");
  requestsList.replaceChildren();
  try {
    const { requests } = await portalRequest("/api/teacher/requests");
    requestsPanel.hidden = requests.length === 0;
    requests.forEach((request) => {
      const row = document.createElement("div");
      row.className = "teacher-request-row";
      const details = document.createElement("p");
      details.textContent = `${request.name} · ${request.staffId} · ${request.username}`;
      const approveButton = document.createElement("button");
      approveButton.className = "button button-green";
      approveButton.type = "button";
      approveButton.textContent = "Approve teacher";
      approveButton.addEventListener("click", async () => {
        approveButton.disabled = true;
        try {
          await portalRequest(`/api/teacher/requests/${request.id}/approve`, { method: "POST", body: "{}" });
          await loadTeacherPortal(user);
        } catch (error) {
          approveButton.disabled = false;
          document.querySelector("#student-create-feedback").textContent = error.message;
        }
      });
      row.append(details, approveButton);
      requestsList.append(row);
    });
  } catch (error) {
    document.querySelector("#student-create-feedback").textContent = error.message;
  }
}

async function showSignedInUser(user) {
  if (user.role === "teacher") await loadTeacherPortal(user);
  else if (user.role === "student") await loadStudentPortal(user);
  else showPortalPanel(null);
}

document.querySelector("#portal-login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  const credentials = Object.fromEntries(new FormData(form));
  credentials.role = currentLoginRole;
  loginFeedback.textContent = "Signing in...";
  try {
    const { user } = await portalRequest("/api/login", { method: "POST", body: JSON.stringify(credentials) });
    form.reset();
    await showSignedInUser(user);
  } catch (error) {
    loginFeedback.textContent = error.message;
  }
});

document.querySelector("#teacher-signup-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  const feedback = document.querySelector("#teacher-signup-feedback");
  feedback.textContent = "Sending account request...";
  try {
    await portalRequest("/api/teacher-signup", {
      method: "POST",
      body: JSON.stringify(Object.fromEntries(new FormData(form)))
    });
    form.reset();
    showPortalEntry("choice");
    portalEntryFeedback.textContent = "Teacher request sent. An approved teacher must approve the account before it can access student records.";
  } catch (error) {
    feedback.textContent = error.message;
  }
});

document.querySelectorAll(".portal-logout").forEach((button) => {
  button.addEventListener("click", async () => {
    try { await portalRequest("/api/logout", { method: "POST", body: "{}" }); } catch {}
    showPortalPanel(null);
    loginFeedback.textContent = "You have signed out.";
  });
});

document.querySelector("#student-create-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  const feedback = document.querySelector("#student-create-feedback");
  try {
    const { student } = await portalRequest("/api/teacher/students", {
      method: "POST",
      body: JSON.stringify(Object.fromEntries(new FormData(form)))
    });
    form.reset();
    await loadTeacherPortal({ name: document.querySelector("#teacher-welcome").textContent });
    feedback.textContent = `Account created for ${student.name}. Give the student their username and temporary password securely.`;
  } catch (error) {
    feedback.textContent = error.message;
  }
});

document.querySelector("#teacher-results-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  const feedback = document.querySelector("#teacher-results-feedback");
  const data = Object.fromEntries(new FormData(form));
  data.score = Number(data.score);
  data.outOf = Number(data.outOf);
  try {
    await portalRequest("/api/teacher/results", { method: "POST", body: JSON.stringify(data) });
    feedback.textContent = "Result saved to the school records.";
    form.reset();
    document.querySelector("#result-student").value = data.studentId;
  } catch (error) {
    feedback.textContent = error.message;
  }
});

portalRequest("/api/me")
  .then(({ user }) => showSignedInUser(user))
  .catch(() => {
    if (!portalChoice.hidden) {
      portalEntryFeedback.textContent = "Choose student sign-in, teacher sign-in, or teacher sign-up.";
    }
  });

if (window.location.hash === "#teacher-login") {
  showPortalEntry("teacher-login");
}
