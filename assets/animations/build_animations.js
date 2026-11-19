// Builds starter animation files for Roblox's Animation Editor from the poses in
// src/shared/Config/SwingAnimations.luau. Run: node assets/animations/build_animations.js
// Each output .rbxmx holds one KeyframeSequence you can import, tweak and publish in Studio.
const fs = require("fs");
const path = require("path");

// Joint name in the config -> the body part that joint moves (what an animation stores).
const PART_OF = {
  Root: "LowerTorso",
  Waist: "UpperTorso",
  LeftShoulder: "LeftUpperArm",
  RightShoulder: "RightUpperArm",
  LeftElbow: "LeftLowerArm",
  RightElbow: "RightLowerArm",
  LeftHip: "LeftUpperLeg",
  RightHip: "RightUpperLeg",
  LeftKnee: "LeftLowerLeg",
  RightKnee: "RightLowerLeg",
};

// The rig's shape. An animation stores poses in this same nesting.
const TREE = {
  name: "HumanoidRootPart",
  children: [
    {
      name: "LowerTorso",
      children: [
        {
          name: "UpperTorso",
          children: [
            { name: "LeftUpperArm", children: [{ name: "LeftLowerArm", children: [] }] },
            { name: "RightUpperArm", children: [{ name: "RightLowerArm", children: [] }] },
          ],
        },
        { name: "LeftUpperLeg", children: [{ name: "LeftLowerLeg", children: [] }] },
        { name: "RightUpperLeg", children: [{ name: "RightLowerLeg", children: [] }] },
      ],
    },
  ],
};

const rad = (d) => (d * Math.PI) / 180;

// CFrame.Angles(x, y, z): turn about X, then Y, then Z.
function matrix(xDeg, yDeg, zDeg) {
  const [x, y, z] = [rad(xDeg), rad(yDeg), rad(zDeg)];
  const [cx, sx, cy, sy, cz, sz] = [Math.cos(x), Math.sin(x), Math.cos(y), Math.sin(y), Math.cos(z), Math.sin(z)];
  return [
    cy * cz, -cy * sz, sy,
    sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy,
    -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy,
  ];
}

function poseXml(node, pose, depth) {
  const pad = "\t".repeat(depth);
  const joint = Object.keys(PART_OF).find((j) => PART_OF[j] === node.name);
  const angles = (joint && pose[joint]) || [0, 0, 0];
  const m = matrix(angles[0], angles[1], angles[2]);
  const children = node.children.map((child) => poseXml(child, pose, depth + 1)).join("");
  return (
    `${pad}<Item class="Pose">\n` +
    `${pad}\t<Properties>\n` +
    `${pad}\t\t<string name="Name">${node.name}</string>\n` +
    `${pad}\t\t<CoordinateFrame name="CFrame">\n` +
    `${pad}\t\t\t<X>0</X><Y>0</Y><Z>0</Z>\n` +
    m.map((v, i) => `${pad}\t\t\t<R${Math.floor(i / 3)}${i % 3}>${v.toFixed(6)}</R${Math.floor(i / 3)}${i % 3}>\n`).join("") +
    `${pad}\t\t</CoordinateFrame>\n` +
    `${pad}\t\t<float name="Weight">1</float>\n` +
    `${pad}\t</Properties>\n` +
    children +
    `${pad}</Item>\n`
  );
}

function build(name, keyframes) {
  const body = keyframes
    .map(
      (key) =>
        `\t\t<Item class="Keyframe">\n` +
        `\t\t\t<Properties>\n` +
        `\t\t\t\t<string name="Name">Keyframe</string>\n` +
        `\t\t\t\t<float name="Time">${key.t}</float>\n` +
        `\t\t\t</Properties>\n` +
        poseXml(TREE, key.pose, 3) +
        `\t\t</Item>\n`
    )
    .join("");
  return (
    `<roblox version="4">\n` +
    `\t<Item class="KeyframeSequence">\n` +
    `\t\t<Properties>\n` +
    `\t\t\t<string name="Name">${name}</string>\n` +
    `\t\t\t<bool name="Loop">false</bool>\n` +
    `\t\t\t<token name="Priority">3</token>\n` +
    `\t\t</Properties>\n` +
    body +
    `\t</Item>\n` +
    `</roblox>\n`
  );
}

// Same poses as Config/SwingAnimations, as [X, Y, Z] degrees per joint.
const ANIMATIONS = {
  Swing1: [
    { t: 0, pose: {} },
    { t: 0.1, pose: { RightShoulder: [85, 0, 70], RightElbow: [35, 0, 0], LeftShoulder: [12, 0, -12], Waist: [0, -55, 0], Root: [-10, -12, 0], RightHip: [-15, 0, 0], LeftHip: [10, 0, 0] } },
    { t: 0.22, pose: { RightShoulder: [92, 0, -55], RightElbow: [8, 0, 0], LeftShoulder: [8, 0, -6], Waist: [0, 55, 0], Root: [-16, 15, 0], RightHip: [18, 0, 0], RightKnee: [-20, 0, 0], LeftHip: [-12, 0, 0] } },
    { t: 0.3, pose: { RightShoulder: [88, 0, -72], RightElbow: [8, 0, 0], Waist: [0, 65, 0], Root: [-12, 18, 0] } },
    { t: 0.5, pose: {} },
  ],
  Swing2: [
    { t: 0, pose: {} },
    { t: 0.1, pose: { RightShoulder: [80, 0, -60], RightElbow: [40, 0, 0], LeftShoulder: [8, 0, -6], Waist: [0, 50, 0], Root: [-10, 12, 0], LeftHip: [-15, 0, 0] } },
    { t: 0.22, pose: { RightShoulder: [95, 0, 65], RightElbow: [8, 0, 0], LeftShoulder: [14, 0, -14], Waist: [0, -55, 0], Root: [-16, -15, 0], LeftHip: [18, 0, 0], LeftKnee: [-20, 0, 0] } },
    { t: 0.3, pose: { RightShoulder: [90, 0, 78], RightElbow: [8, 0, 0], Waist: [0, -62, 0], Root: [-12, -18, 0] } },
    { t: 0.5, pose: {} },
  ],
  Swing3: [
    { t: 0, pose: {} },
    { t: 0.12, pose: { RightShoulder: [-145, 0, 20], RightElbow: [45, 0, 0], LeftShoulder: [10, 0, -8], Waist: [0, -30, 0], Root: [8, 0, 0], RightHip: [-18, 0, 0] } },
    { t: 0.24, pose: { RightShoulder: [-305, 0, -15], RightElbow: [10, 0, 0], LeftShoulder: [10, 0, -5], Waist: [0, 35, 0], Root: [-22, 0, 0], RightHip: [20, 0, 0], RightKnee: [-25, 0, 0] } },
    { t: 0.33, pose: { RightShoulder: [-325, 0, -25], RightElbow: [8, 0, 0], Waist: [0, 42, 0], Root: [-18, 0, 0] } },
    { t: 0.55, pose: { RightShoulder: [-360, 0, 0] } },
  ],
  DashSlash: [
    { t: 0, pose: {} },
    { t: 0.08, pose: { RightShoulder: [110, 0, 75], RightElbow: [50, 0, 0], LeftShoulder: [12, 0, -12], Waist: [0, -45, 0], Root: [-30, 0, 0], RightHip: [-20, 0, 0] } },
    { t: 0.2, pose: { RightShoulder: [95, 0, -55], RightElbow: [8, 0, 0], LeftShoulder: [20, 0, -15], Waist: [0, 55, 0], Root: [-38, 0, 0], RightHip: [25, 0, 0], RightKnee: [-30, 0, 0] } },
    { t: 0.32, pose: { RightShoulder: [85, 0, -70], RightElbow: [8, 0, 0], LeftShoulder: [16, 0, -12], Waist: [0, 65, 0], Root: [-28, 0, 0] } },
    { t: 0.55, pose: {} },
  ],
  Skyfall: [
    { t: 0, pose: {} },
    { t: 0.12, pose: { RightShoulder: [-25, 0, 12], LeftShoulder: [-20, 0, -12], Root: [-12, 0, 0], RightKnee: [-35, 0, 0], LeftKnee: [-35, 0, 0] } },
    { t: 0.34, pose: { RightShoulder: [-152, 0, 12], RightElbow: [35, 0, 0], LeftShoulder: [-162, 0, -12], Root: [15, 0, 0], RightKnee: [-45, 0, 0] } },
    { t: 0.5, pose: { RightShoulder: [-155, 0, 12], RightElbow: [35, 0, 0], LeftShoulder: [-165, 0, -12], Root: [15, 0, 0], RightKnee: [-45, 0, 0] } },
    { t: 0.62, pose: { RightShoulder: [-322, 0, 5], RightElbow: [5, 0, 0], LeftShoulder: [-315, 0, -5], Root: [-32, 0, 0], RightHip: [22, 0, 0], RightKnee: [-30, 0, 0] } },
    { t: 0.74, pose: { RightShoulder: [-322, 0, 5], RightElbow: [5, 0, 0], LeftShoulder: [-315, 0, -5], Root: [-30, 0, 0], RightHip: [18, 0, 0] } },
    { t: 0.9, pose: { RightShoulder: [-360, 0, 0], LeftShoulder: [-360, 0, 0] } },
  ],
  WaveSlash: [
    { t: 0, pose: {} },
    { t: 0.17, pose: { RightShoulder: [-160, 0, 55], RightElbow: [45, 0, 0], LeftShoulder: [12, 0, -12], Waist: [0, -50, 0], RightHip: [-20, 0, 0] } },
    { t: 0.3, pose: { RightShoulder: [-300, 0, -45], RightElbow: [8, 0, 0], LeftShoulder: [8, 0, -6], Waist: [0, 58, 0], Root: [-14, 12, 0], RightHip: [22, 0, 0], RightKnee: [-25, 0, 0] } },
    { t: 0.4, pose: { RightShoulder: [-315, 0, -60], RightElbow: [8, 0, 0], Waist: [0, 66, 0], Root: [-10, 14, 0] } },
    { t: 0.65, pose: { RightShoulder: [-360, 0, 0] } },
  ],
  // The spin is cut into 90 degree steps: a single 720 degree turn would be smoothed away to no turn at all.
  Whirlwind: (() => {
    const arms = { RightShoulder: [10, 0, 85], LeftShoulder: [10, 0, -75], RightElbow: [5, 0, 0] };
    const frames = [{ t: 0, pose: {} }, { t: 0.14, pose: { ...arms, Root: [-10, 0, 0], RightKnee: [-25, 0, 0] } }];
    for (let i = 1; i <= 8; i++) {
      frames.push({ t: 0.14 + (0.64 * i) / 8, pose: { ...arms, Root: [-10, 90 * i, 0] } });
    }
    frames.push({ t: 1.0, pose: {} });
    return frames;
  })(),
};

// Roblox turns a limb the shortest way between two poses, so a big swing over the head would cut
// straight through the front instead. Splitting every big step into smaller ones forces the real path.
const MAX_STEP_DEGREES = 45;

function subdivide(keyframes) {
  const out = [keyframes[0]];
  for (let i = 1; i < keyframes.length; i++) {
    const [a, b] = [keyframes[i - 1], keyframes[i]];
    const joints = new Set([...Object.keys(a.pose), ...Object.keys(b.pose)]);
    let biggest = 0;
    for (const joint of joints) {
      const [from, to] = [a.pose[joint] || [0, 0, 0], b.pose[joint] || [0, 0, 0]];
      biggest = Math.max(biggest, ...from.map((v, axis) => Math.abs(to[axis] - v)));
    }
    const steps = Math.max(1, Math.ceil(biggest / MAX_STEP_DEGREES));
    for (let step = 1; step <= steps; step++) {
      const f = step / steps;
      const pose = {};
      for (const joint of joints) {
        const [from, to] = [a.pose[joint] || [0, 0, 0], b.pose[joint] || [0, 0, 0]];
        pose[joint] = from.map((v, axis) => v + (to[axis] - v) * f);
      }
      out.push({ t: a.t + (b.t - a.t) * f, pose });
    }
  }
  return out;
}

const outDir = path.join(__dirname);
for (const [name, keyframes] of Object.entries(ANIMATIONS)) {
  const file = path.join(outDir, name + ".rbxmx");
  const dense = subdivide(keyframes);
  fs.writeFileSync(file, build(name, dense));
  console.log("wrote", file, dense.length, "keyframes (from", keyframes.length + ")");
}
