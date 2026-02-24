# -*- coding: utf-8 -*-
#
#  Copyright (c) 2024 Jianshan Jiang
#
import os
from graphlib import TopologicalSorter, CycleError
from collections import deque
from pathlib import Path
from rich.tree import Tree
from rich.text import Text

from mpt.config import LibraryConfig
from mpt.log import RichLogger
from mpt.view import RichTable, RichPanel


class DependencyResolver:

    @staticmethod
    def parse_dependency_name(dep_name):
        """
        Supports the following input formats:
        - "library" -> (library, None, None)
        - "library:required" -> (library, "required", None)
        """
        parts = dep_name.split(':')
        if len(parts) == 1:
            # Format: "library"
            return parts[0], None
        elif len(parts) == 2:
            # Format: "library:type"
            return parts[0], parts[1]
        else:
            # Invalid format - log warning and return original name
            RichLogger.warning(f"Invalid dependency format: {dep_name}")
            return dep_name, None


    @staticmethod
    def get_dependencies(lib, dep_type=None):
        config = LibraryConfig.load(lib)
        if not config:
            RichLogger.error(f"[[bold cyan]{lib}[/bold cyan]] Failed to load library configuration")
            return []
        deps = config.get('dependencies', {}) or {}
        if dep_type is None:
            # Combine both required and optional dependencies
            required_deps = deps.get('required', []) or []
            optional_deps = deps.get('optional', []) or []
            all_deps = required_deps + optional_deps
        else:
            # Return only dependencies of the specified type
            all_deps = deps.get(dep_type, []) or []
        return all_deps


    @staticmethod
    def build_tree(triplet, root):
        graph = {}
        visited = set()
        queue = deque([root])
        try:
            # Extract target OS from triplet (e.g., "windows" from "x86_64-pc-windows-msvc")
            target_os = triplet.split('-')[2]
            while queue:
                current_node = queue.popleft()
                if current_node in visited:
                    continue
                visited.add(current_node)
                lib, dep_type = DependencyResolver.parse_dependency_name(current_node)
                # Check if library supports the target platform
                config = LibraryConfig.load(lib)
                if config:
                    supports = config.get('supports', [])
                    if supports and target_os not in supports:
                        RichLogger.info(f"Skipping {lib}: not supported on {target_os}")
                        continue  # Skip unsupported libraries entirely
                # Get dependencies for the current node
                dependencies = DependencyResolver.get_dependencies(lib, dep_type)
                graph[current_node] = set(dependencies)

                # Add dependencies to the queue for further processing
                for dep in dependencies:
                    if dep not in visited:
                        queue.append(dep)
        except Exception as e:
            RichLogger.exception(f"Failed to build dependency tree for root '{root}': {str(e)}")
            raise
        return graph


    @staticmethod
    def topological_sort(root, graph):
        try:
            # Create topological sorter and get static order
            ts = TopologicalSorter(graph)
            order = list(ts.static_order())
            order_table = RichTable.create(
                title=f"[[bold cyan]{root}[/bold cyan]] Build Order",
                show_header=True,
                header_style="bold cyan"
            )
            RichTable.add_column(order_table, "Step", style="cyan", justify="right", no_wrap=True)
            RichTable.add_column(order_table, "Library", style="bold yellow")
            for i, node in enumerate(order, 1):
                RichTable.add_row(order_table, str(i), node)
            RichTable.render(order_table)
            return order
        except CycleError as e:
            RichLogger.exception(f"[[bold cyan]{root}[/bold cyan]] Cycle detected: {str(e)}")
            raise


    @staticmethod
    def render_tree(root, graph):
        RichLogger.info(f"[[bold cyan]{root}[/bold cyan]] Rendering dependency tree with [bold yellow]{len(graph)}[/bold yellow] nodes")
        # Create the root node of the tree
        tree = Tree(f"🌳 [bold green]{root}[/bold green]", guide_style="dim")
        visited = set()
        queue = deque([(root, tree, 0)])
        # Use BFS to build the visual tree structure
        while queue:
            node_name, parent_node, depth = queue.popleft()
            if node_name in visited:
                continue
            visited.add(node_name)

            dependencies = graph.get(node_name, set())
            for dep_node in dependencies:
                # Check if the dependency node has children
                has_children = dep_node in graph and graph[dep_node] and dep_node not in visited
                # Choose appropriate icon based on whether node has children
                icon = "🌿" if has_children else "🍃"
                display_name = f"{icon} {dep_node}"
                # Create child node in the visual tree
                node = parent_node.add(Text(display_name, style="bold" if depth < 2 else ""))

                # If the node has children, add it to the queue for expansion
                if has_children:
                    queue.append((dep_node, node, depth + 1))
        # Display the completed tree
        RichLogger.print(tree)


    @staticmethod
    def resolve(arch, root, build=False):
        from mpt.build import BuildManager
        triplet = BuildManager.get_triplet(arch)
        # Build the complete dependency graph
        graph = DependencyResolver.build_tree(triplet, root)
        # Render visual representation of the dependency tree
        DependencyResolver.render_tree(root, graph)
        # Get topological order for processing
        order = DependencyResolver.topological_sort(root, graph)
        # Execute build process if requested
        if build:
            for node_name in order:
                lib, _ = DependencyResolver.parse_dependency_name(node_name)
                config = LibraryConfig.load(lib)
                if not config:
                    RichLogger.error(f"[[bold cyan]{root}[/bold cyan]] Failed to load configuration for [bold cyan]{lib}[/bold cyan]")
                    return False
                success = BuildManager.build_library(arch, node_name, config)
                if not success:
                   RichLogger.error(f"[[bold cyan]{root}[/bold cyan]] Build failed for [bold cyan]{node_name}[/bold cyan]")
                   return False
        return True
