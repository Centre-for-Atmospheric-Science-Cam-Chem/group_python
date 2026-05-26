import matplotlib.pyplot as plt


def create_custom_subplots(
    widths_subplot,
    heights_subplot,
    fig_width: float = 6,
    fig_ratio: float = 0.7,
    excluded_bottom_rows: int = 0,
):

    fig = plt.figure(figsize=(fig_width, fig_width * fig_ratio))

    nrow = len(heights_subplot)
    ncol = len(widths_subplot)

    gs = fig.add_gridspec(
        nrow, ncol, width_ratios=widths_subplot, height_ratios=heights_subplot
    )

    if nrow - excluded_bottom_rows < 0:
        raise ValueError("nrow < 0")

    axs = [
        fig.add_subplot(gs[i, j])
        for i in range(nrow - excluded_bottom_rows)
        for j in range(ncol)
    ]

    return fig, axs, gs, nrow, ncol
