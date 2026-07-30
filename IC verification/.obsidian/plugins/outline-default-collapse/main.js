const { ItemView, Plugin, MarkdownView, setIcon } = require("obsidian");

const VIEW_TYPE = "stable-outline-view";

module.exports = class StableOutlinePlugin extends Plugin {
    async onload() {
        this.registerView(VIEW_TYPE, (leaf) => new StableOutlineView(leaf, this));

        this.addRibbonIcon("list-tree", "Open Stable Outline", () => {
            this.activateView();
        });

        this.addCommand({
            id: "open-stable-outline",
            name: "Open Stable Outline",
            callback: () => this.activateView(),
        });

        this.registerEvent(
            this.app.workspace.on("active-leaf-change", () => this.refreshViews())
        );
        this.registerEvent(
            this.app.workspace.on("file-open", () => this.refreshViews())
        );
        this.registerEvent(
            this.app.metadataCache.on("changed", () => this.refreshViews())
        );
    }

    onunload() {
        this.app.workspace.detachLeavesOfType(VIEW_TYPE);
    }

    async activateView() {
        const existing = this.app.workspace.getLeavesOfType(VIEW_TYPE)[0];
        if (existing) {
            this.app.workspace.revealLeaf(existing);
            this.refreshViews();
            return;
        }

        const leaf = this.app.workspace.getRightLeaf(false);
        await leaf.setViewState({
            type: VIEW_TYPE,
            active: true,
        });
        this.app.workspace.revealLeaf(leaf);
    }

    refreshViews() {
        for (const leaf of this.app.workspace.getLeavesOfType(VIEW_TYPE)) {
            if (leaf.view && leaf.view.refresh) {
                leaf.view.refresh();
            }
        }
    }
};

class StableOutlineView extends ItemView {
    constructor(leaf, plugin) {
        super(leaf);
        this.plugin = plugin;
        this.openKeys = new Set();
        this.filePath = null;
    }

    getViewType() {
        return VIEW_TYPE;
    }

    getDisplayText() {
        return "Stable Outline";
    }

    getIcon() {
        return "list-tree";
    }

    async onOpen() {
        this.contentEl.addClass("stable-outline");
        this.refresh();
    }

    refresh() {
        const file = this.app.workspace.getActiveFile();
        this.contentEl.empty();

        if (!file || file.extension !== "md") {
            this.contentEl.createEl("div", {
                cls: "stable-outline-empty",
                text: "No active Markdown file",
            });
            return;
        }

        if (this.filePath !== file.path) {
            this.filePath = file.path;
            this.openKeys.clear();
        }

        const cache = this.app.metadataCache.getFileCache(file);
        const headings = cache && cache.headings ? cache.headings : [];

        if (headings.length === 0) {
            this.contentEl.createEl("div", {
                cls: "stable-outline-empty",
                text: "No headings",
            });
            return;
        }

        const tree = this.buildTree(headings);
        const root = this.contentEl.createDiv({ cls: "stable-outline-root" });

        for (const node of tree) {
            this.renderNode(root, node, file, 0);
        }
    }

    buildTree(headings) {
        const root = [];
        const stack = [];

        for (let index = 0; index < headings.length; index++) {
            const heading = headings[index];
            const title = this.stripHtml(heading.heading);
            const node = {
                heading,
                title,
                index,
                key: `${heading.level}:${heading.position.start.line}:${title}`,
                children: [],
            };

            while (stack.length > 0 && stack[stack.length - 1].heading.level >= heading.level) {
                stack.pop();
            }

            if (stack.length === 0) {
                root.push(node);
            } else {
                stack[stack.length - 1].children.push(node);
            }

            stack.push(node);
        }

        return root;
    }

    renderNode(parent, node, file, depth) {
        const item = parent.createDiv({
            cls: `tree-item stable-outline-node stable-outline-level-${node.heading.level}`,
        });
        item.style.setProperty("--stable-outline-depth", String(depth));

        const hasChildren = node.children.length > 0;
        const defaultOpen = depth === 0;
        const isOpen = this.openKeys.has(node.key) || (defaultOpen && !this.openKeys.has(`closed:${node.key}`));

        if (!isOpen) {
            item.addClass("is-collapsed");
        }

        const row = item.createDiv({
            cls: "tree-item-self stable-outline-self",
        });

        const toggle = row.createDiv({ cls: "tree-item-icon collapse-icon stable-outline-toggle" });
        if (hasChildren) {
            setIcon(toggle, isOpen ? "chevron-down" : "chevron-right");
            toggle.addEventListener("click", (event) => {
                event.preventDefault();
                event.stopPropagation();

                if (isOpen) {
                    this.openKeys.delete(node.key);
                    this.openKeys.add(`closed:${node.key}`);
                } else {
                    this.openKeys.add(node.key);
                    this.openKeys.delete(`closed:${node.key}`);
                }

                this.refresh();
            });
        } else {
            toggle.empty();
            toggle.addClass("stable-outline-toggle-empty");
        }

        const title = row.createDiv({
            cls: "tree-item-inner stable-outline-title",
            text: node.title,
        });
        row.addEventListener("click", (event) => {
            if (event.target === toggle || toggle.contains(event.target)) {
                return;
            }

            this.goToHeading(file, node);
        });

        if (hasChildren && isOpen) {
            const children = item.createDiv({ cls: "tree-item-children stable-outline-children" });
            for (const child of node.children) {
                this.renderNode(children, child, file, depth + 1);
            }
        }
    }

    async goToHeading(file, node) {
        const leaf = this.getTargetMarkdownLeaf(file);
        const line = node.heading.position.start.line;

        await leaf.openFile(file, {
            active: true,
            eState: { line },
        });
        this.app.workspace.revealLeaf(leaf);

        window.requestAnimationFrame(() => this.scrollToNode(leaf, node));
        window.setTimeout(() => this.scrollToNode(leaf, node), 50);
        window.setTimeout(() => this.scrollToNode(leaf, node), 150);
    }

    scrollToNode(leaf, node) {
        const view = leaf.view;
        if (!(view instanceof MarkdownView)) {
            return;
        }

        const line = node.heading.position.start.line;
        if (typeof view.setEphemeralState === "function") {
            view.setEphemeralState({ line });
        }

        const mode = typeof view.getMode === "function" ? view.getMode() : "source";
        if (mode !== "preview" && view.editor) {
            view.editor.setCursor({ line, ch: 0 });
            view.editor.scrollIntoView(
                {
                    from: { line, ch: 0 },
                    to: { line, ch: 0 },
                },
                true
            );
            return;
        }

        const previewEl = view.containerEl.querySelector(".markdown-preview-view");
        if (!previewEl) {
            return;
        }

        const headingEls = Array.from(previewEl.querySelectorAll("h1, h2, h3, h4, h5, h6"));
        const headingEl = headingEls[node.index];
        if (headingEl) {
            headingEl.scrollIntoView({ block: "start" });
        }
    }

    getTargetMarkdownLeaf(file) {
        const activeLeaf = this.app.workspace.activeLeaf;
        if (
            activeLeaf &&
            activeLeaf.view instanceof MarkdownView &&
            activeLeaf.view.file &&
            activeLeaf.view.file.path === file.path
        ) {
            return activeLeaf;
        }

        const markdownLeaves = this.app.workspace.getLeavesOfType("markdown");
        const sameFileLeaf = markdownLeaves.find((leaf) => (
            leaf.view instanceof MarkdownView &&
            leaf.view.file &&
            leaf.view.file.path === file.path
        ));

        if (sameFileLeaf) {
            return sameFileLeaf;
        }

        const anyMarkdownLeaf = markdownLeaves.find((leaf) => leaf.view instanceof MarkdownView);
        if (anyMarkdownLeaf) {
            return anyMarkdownLeaf;
        }

        return this.app.workspace.getLeaf("tab");
    }

    stripHtml(value) {
        if (!value) return "";

        const div = document.createElement("div");
        div.innerHTML = value;
        return (div.textContent || div.innerText || value)
            .replace(/\s+/g, " ")
            .trim();
    }
}
